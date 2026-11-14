# k3s restarts only on a drained node

Status: accepted

A colmena deploy on 2026-11-14 restarted `k3s.service` on the server (junior) and
on the agents at the same time (#249). The trigger was a re-encrypted
`secrets/hosts/k3s.yaml`, which is a restart trigger for k3s. The journals on d2
and junior show the following sequence:

1. junior's API server started at 00:43:11.8, and its `node_authorizer` cache
   synced at 00:43:12.96.
2. Between those two moments, d2's freshly restarted kubelet populated its desired
   state of the world. Every PVC lookup failed: `User "system:node:d2" cannot get
   resource "persistentvolumeclaims" ... no relationship found between node 'd2'
   and this object`.
3. Kubelet finished populating without those volumes and unmounted all six
   synology-csi volumes, logging out of their iSCSI sessions, while their pods
   kept running.
4. The containers' mount namespaces still held the logged-out devices, so their
   filesystems went read-only or returned I/O errors. Writes were lost until the
   pods were deleted by hand.

So the hazard is a kubelet that starts while the API server it talks to is
still starting. It does not depend on a k3s version change. Even without a
secret change, the k3s store path changes whenever nixpkgs rebuilds its
dependencies (coreutils, systemd, tzdata in the unit's `PATH`), with the version
string unchanged, so `nix store diff-closures` shows nothing (commit e7933b6, for
example). Restart-on-change would therefore restart the server and agents
together on almost every nixpkgs bump.

## Decision

- **`systemd.services.k3s.restartIfChanged = false`** (in `k3s-node`, so on the
  server and the agents). A switch prints `NOT restarting the following changed
  units: k3s.service` and leaves k3s running the old generation. The obsolete
  `restartTriggers` on the registry secret are removed, because they had no effect.
- **Kubelet graceful node shutdown** (`services.k3s.gracefulNodeShutdown`, 90s,
  30s of it for critical pods), with logind's `InhibitDelayMaxSec` raised to
  match. On reboot or poweroff, kubelet stops pods and unmounts their volumes before
  systemd stops iscsid and the network.
- Pending changes are applied by a **rolling reboot**: drain, reboot into the new
  generation, wait for Ready, uncordon, one node at a time. Two drivers do this:
  - **`nix run .#k3s-roll`** (hands-on). It is synchronous and runs from a
    machine with cluster-admin `kubectl`. It does the server first.
  - **kured** (unattended, in myks-homelab). After `colmena apply boot`, kured
    reboots every node whose `k3s-reboot-required` sentinel reports a pending
    generation, one at a time under its cluster lock.

## Procedure

Hands-on, all nodes (control-plane first) or the named ones:

```bash
nix run .#k3s-roll                    # server, then agents
nix run .#k3s-roll -- d2 d3           # only these, in this order
nix run .#k3s-roll -- d2 -- --verbose # extra args go to `colmena apply`
```

Unattended: `colmena apply boot` (or `switch`) and let kured roll the fleet.

`k3s-reboot-required` (on every k3s node) exits 0 when the generation selected for
next boot differs from the booted one in the kernel, initrd, kernel modules,
systemd, or `k3s.service`. It cannot see a k3s that was restarted by hand after
the switch. Such a node gets one extra reboot. Changes to `registries.yaml`
alone are not detected: run `k3s-roll` on the affected nodes.

`k3s-roll` and kured must not run at the same time, because they do not share a lock.
Suspend kured during a hands-on roll, or let kured finish its queue first.

After a **k3s minor upgrade**, roll the server by hand first
(`nix run .#k3s-roll -- junior`). kured reboots nodes in no particular order and
could start a newer agent against an older server.

## Considered options

- **Keep restarting and add an `ExecStop` drain.** Rejected. `ExecStop` also runs on
  every switch, and evicting pods needs cluster-admin rights, which the agent's
  kubelet credentials do not have (the node authorizer forbids evictions).
- **Tune restart triggers so k3s restarts only on real changes.** Rejected. A
  nixpkgs bump is a real change to the unit, and a k3s upgrade still restarts it
  under live pods.
- **`colmena apply --reboot --parallel 1` alone.** colmena has no pre- or
  post-activation hooks, so it cannot drain. Graceful shutdown would kill pods
  instead of evicting them (PDBs ignored, no rescheduling before the node goes
  down), and colmena moves on as soon as SSH answers, not when the node is Ready.
  `k3s-roll` wraps it per node.
- **kured only.** It runs unattended, but it cannot order the server first and
  failures surface later. It is kept for routine rollouts, with `k3s-roll` for
  hands-on rollouts and k3s minor upgrades.

## Consequences

- A deploy can leave k3s on an older generation until the node is cycled or
  rebooted. The switch output says so, but colmena hides that output on success.
- `Restart=always` uses the unit currently on disk. If k3s crashes after a switch,
  systemd starts the new generation, undrained, at an unplanned time.
- k3s version skew becomes manual. An agent must never run a newer k3s than the
  server, so after a k3s upgrade the server is cycled first.
- Deploying this change does not restart k3s, because
  `switch-to-configuration` reads `X-RestartIfChanged` from the new unit.
- Graceful shutdown terminates the synology-csi node plugin together with ordinary
  pods unless that pod is critical. Its DaemonSet (in myks-homelab) needs
  `priorityClassName: system-node-critical`. Otherwise, kubelet may unstage volumes
  after the plugin is gone, and iSCSI sessions stay logged in until the network
  drops. This is a prerequisite for graceful shutdown to protect iSCSI volumes
  (Zebradil/myks-homelab#1185).
- Whether kubelet waits for volume teardown before releasing the inhibitor lock
  depends on the kubelet version and is **unverified** on k3s 1.36. The first planned
  reboot is the test (see the recovery check in #249).
