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
