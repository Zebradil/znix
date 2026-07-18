# znix

A unified Nix configuration (dendritic pattern via flake-parts) for personal and work
hosts.

The net-local binary-cache product (box + remote cache design, eager bidirectional
replication, root-manifest discovery) has moved to
[`kasha`](https://github.com/Zebradil/kasha) — see its `CONTEXT.md` for that
terminology. znix remains kasha's reference consumer/deployment: its remote cache is
`znix.zebradil.dev`, backed by Cloudflare R2.

## Language

**Integrated mode**:
Home-manager evaluated *inside* a NixOS/Darwin system (`home-manager.users.<user>`),
so a system switch also builds and activates home.
_Avoid_: embedded, inline home.

**Standalone home**:
Home-manager evaluated on its own as `homeConfigurations."<user>@<host>"`, switched
with `home-manager switch` independently of the system. See ADR-0002.

**The osConfig seam**:
`osConfig` is the system config a home module can read *only* in integrated mode. Every
`osConfig.znix.*` read is a dependency on the system eval; the split severs it by moving
those option definitions to home scope.

**user@host key**:
The identifier for a standalone home config (e.g. `zebradil@tuxedo`). The `@host` part is
where a host's nixpkgs pin and host-specific home settings attach.
_Avoid_: per-user config, home profile.

**Appliance vs fleet**:
An _appliance_ is a bespoke one-off host with its own hand-written module (`toddler`),
divergences justified per-host (see ADR-0001). A _fleet_ is several near-identical hosts
sharing one base module, deployed as cattle via a colmena tag (`dell1/2/3`, tag `k3s`).
Appliance = pet with a reason; fleet = interchangeable base + thin per-host overrides.

**k3s server / agent**:
The canonical role names, taken from k3s's own vocabulary. A _server_ is a control-plane
node; an _agent_ is a worker. Prefer these over the ambiguous "master/worker" — the k8s
control plane is not the SQLite/etcd datastore, and "worker" hides the kubelet↔apiserver
skew rule (an agent may match the server minor or trail by one, never lead).
_Avoid_: master, minion, worker (in config/identifiers).

**Node identity**:
A cluster node's stable identifier is its **hostname** (`--node-name`), never its IP. The
IP is transport only — a node keeps its identity when it moves between NICs (WiFi→USB
Ethernet) or gets a new lease. Design so nothing keys on a node's address for identity.
