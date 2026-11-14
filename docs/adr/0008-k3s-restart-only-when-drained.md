# k3s restarts only on a drained node

Status: accepted

A `nixos-rebuild`/colmena switch restarted `k3s.service` on d2 (#249). After the
restart, kubelet tore down and re-staged every synology-csi iSCSI volume on the
node while their pods kept running. The containers' mount namespaces held the
logged-out devices, so their filesystems went read-only or returned I/O errors. Nothing
restarted them, and writes were lost until the pods were deleted by hand.

Why kubelet did that is still **unverified**. The likely candidates are kubelet's
volume reconstruction after a restart and the synology-csi node plugin's startup.
Either way, a kubelet restart under live iSCSI mounts is unsafe.

The restart was not caused by a k3s change. The k3s store path changes whenever
nixpkgs rebuilds its dependencies (coreutils, systemd, tzdata in the unit's
`PATH`). The version string stays the same, so `nix store diff-closures` shows
nothing. Commit e7933b6 is an example. In practice, almost every deploy that bumps
nixpkgs restarts k3s.

## Decision

- **`systemd.services.k3s.restartIfChanged = false`** (in `k3s-node`, so on the
  server and the agents). A switch prints `NOT restarting the following changed
  units: k3s.service` and leaves k3s running the old generation. The obsolete
  `restartTriggers` on the registry secret are removed, because they had no effect.
- **Kubelet graceful node shutdown** (`services.k3s.gracefulNodeShutdown`, 90s,
  30s of it for critical pods), with logind's `InhibitDelayMaxSec` raised to
  match. On reboot or poweroff, kubelet stops pods and unmounts their volumes before
  systemd stops iscsid and the network.
- Pending k3s changes are applied by **cycling the node**: drain, restart or reboot,
  uncordon, one node at a time.

## Procedure: cycle a node

From a machine with cluster-admin `kubectl`:

```bash
node=d2
kubectl drain "$node" --ignore-daemonsets --delete-emptydir-data
ssh "$node" sudo systemctl restart k3s   # or: sudo reboot
kubectl wait --for=condition=Ready "node/$node" --timeout=5m
kubectl uncordon "$node"
```

To check whether a node is running an older k3s than its current generation, compare
the running binary with the one the unit starts:

```bash
readlink /proc/"$(systemctl show -p MainPID --value k3s)"/exe
systemctl show -p ExecStart --value k3s | grep -o '/nix/store/[^ ;]*'
```

This catches package changes only. Changes to flags or `registries.yaml` leave
the binary the same. After any change to `k3s-node`, cycle every node.

## Considered options

- **Keep restarting and add an `ExecStop` drain.** Rejected. `ExecStop` also runs on
  every switch, and evicting pods needs cluster-admin rights, which the agent's
  kubelet credentials do not have (the node authorizer forbids evictions).
- **Tune restart triggers so k3s restarts only on real changes.** Rejected. A
  nixpkgs bump is a real change to the unit, and a k3s upgrade still restarts it
  under live pods.
- **`colmena apply boot --reboot -p 1` for every fleet upgrade.** Works with graceful
  shutdown, but pods are killed rather than evicted (PDBs are ignored, and pods are not
  rescheduled before the node goes down). It stays available for bulk upgrades. The
  drain procedure is the default.

## Consequences

- A deploy can leave k3s on an older generation until the node is cycled or
  rebooted. The switch output says so, but colmena hides that output on success.
- Graceful shutdown terminates the synology-csi node plugin together with ordinary
  pods unless that pod is critical. Its DaemonSet (in myks-homelab) needs
  `priorityClassName: system-node-critical`. Otherwise, kubelet may unstage volumes
  after the plugin is gone, and iSCSI sessions stay logged in until the network
  drops. This is a prerequisite for graceful shutdown to protect iSCSI volumes.
- Whether kubelet waits for volume teardown before releasing the inhibitor lock
  depends on the kubelet version and is **unverified** on k3s 1.36. The first planned
  reboot is the test (see the recovery check in #249).
