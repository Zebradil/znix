# k3s rolling reboots and restart safety

Status: accepted

A colmena deploy on 2026-11-14 restarted `k3s.service` on the server (junior) and
on the agents at the same time (#249). The trigger was a re-encrypted
`secrets/hosts/k3s.yaml`, which is a k3s restart trigger. The journals on d2 and
junior show the following sequence:

1. junior's API server started at 00:43:11.8, and its `node_authorizer` cache
   synced at 00:43:12.96.
2. Between those two moments, d2's freshly restarted kubelet populated its
   desired state of the world. Every PVC lookup failed: `User "system:node:d2"
   cannot get resource "persistentvolumeclaims" ... no relationship found between
   node 'd2' and this object`.
3. Kubelet finished populating without those volumes and unmounted all six
   synology-csi volumes, logging out of their iSCSI sessions, while their pods
   kept running.
4. The containers' mount namespaces still held the logged-out devices, so their
   filesystems went read-only or returned I/O errors. Writes were lost until the
   pods were deleted by hand.

The hazard is a kubelet that starts while the API server it talks to is still
starting. A k3s restart on an agent while the server is up does not trigger it,
and neither does a server restart while the agents keep running (both
**unverified**, inferred from the sequence above). The k3s store path changes on
most nixpkgs bumps even when the k3s version does not (dependencies in the unit's
`PATH`, commit e7933b6), so a fleet-wide deploy usually restarts k3s everywhere.

## Decision

- **k3s keeps restart-on-change.** The server and the agents are deployed in
  separate colmena runs: first `--on @server`, then, once junior is Ready,
  `--on @k3s`. The tags already keep the server out of `@k3s`. A bare
  `colmena apply`, which targets every node, must not ship a k3s change.
- **Kubelet graceful node shutdown** (`services.k3s.gracefulNodeShutdown`, 90s,
  30s of it for critical pods), with logind's `InhibitDelayMaxSec` raised to
  match. On reboot or poweroff, kubelet stops pods and unmounts their volumes
  before systemd stops iscsid and the network.
- **Rolling reboots** apply changes that need a reboot (kernel, initrd, kernel
  modules, systemd): drain, reboot into the new generation, wait for Ready,
  uncordon, one node at a time. Two drivers do this:
  - **`nix run .#k3s-roll`** (hands-on). It is synchronous and runs from a
    machine with cluster-admin `kubectl`. It does the server first.
  - **kured** (unattended, in myks-homelab). It reboots every node whose
    `k3s-reboot-required` sentinel reports a pending reboot, one at a time under
    its cluster lock.

## Procedure

```bash
colmena apply --on @server            # wait for junior to be Ready
colmena apply --on @k3s               # then the agents

nix run .#k3s-roll                    # rolling reboot: server, then agents
nix run .#k3s-roll -- d2 d3           # only these, in this order
nix run .#k3s-roll -- d2 -- --verbose # extra args go to `colmena apply`
```

`k3s-reboot-required` (on every k3s node) exits 0 when the generation selected
for next boot has a different kernel, initrd, kernel modules or systemd than the
booted one.

`k3s-roll` and kured must not run at the same time, because they do not share a
lock. Suspend kured during a hands-on roll, or let kured finish its queue first.

## Considered options

- **`systemd.services.k3s.restartIfChanged = false`** and applying k3s changes
  only by rolling reboots. Rejected: it has too many downsides.
  - Nodes run a stale k3s (binary, flags, `registries.yaml`) until they reboot,
    and colmena hides the switch's `NOT restarting` notice when the deploy
    succeeds.
  - `Restart=always` starts the new unit after any crash, so changes land
    undrained at an unplanned time anyway.
  - Keeping an agent from running a newer k3s than the server becomes a manual
    duty.
  - Security fixes wait for a reboot.
- **An `ExecStop` drain on k3s.** Rejected. It also runs on every switch, and
  evicting pods needs cluster-admin rights, which the agent's kubelet credentials
  do not have (the node authorizer forbids evictions).
- **`colmena apply --reboot --parallel 1` alone.** colmena has no pre- or
  post-activation hooks, so it cannot drain. Graceful shutdown would kill pods
  instead of evicting them (PDBs ignored, no rescheduling before the node goes
  down), and colmena moves on as soon as SSH answers, not when the node is Ready.
  `k3s-roll` wraps it per node.
- **kured only.** It runs unattended, but it cannot order the server first and
  failures surface later. It is kept for routine rollouts, with `k3s-roll` for
  hands-on ones.

## Consequences

- The deploy split is a convention, not enforced. A bare `colmena apply` that
  changes k3s can repeat #249.
- Graceful shutdown terminates the synology-csi node plugin together with
  ordinary pods unless that pod is critical. Its DaemonSet (in myks-homelab)
  needs `priorityClassName: system-node-critical` (Zebradil/myks-homelab#1185).
- Whether kubelet waits for volume teardown before releasing the inhibitor lock
  depends on the kubelet version and is **unverified** on k3s 1.36. The first
  planned reboot is the test (see the recovery check in #249).
