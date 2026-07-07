# Colmena for remote deploys

Status: accepted

Deploying a remote host meant typing the full
`nixos-rebuild switch --flake .#toddler --target-host suok@toddler --elevate=sudo`
by hand. With one remote host (toddler) today but **six headless x86_64 k3s
nodes coming** (a single-server cluster + one GPU node), a hand-rolled
`nix run .#deploy-<host>` app per host stops scaling: seven near-identical
wrappers, no tags, no parallel deploy. We adopt **colmena** as the deploy tool.

The hive (`modules/flake/colmena.nix`) exposes the `colmenaHive` flake output via
`colmena.lib.makeHive`. Each node **reuses `self.modules.nixos.<host>`** (the same
module set `mkNixos` builds) plus its `nixpkgs.hostPlatform` from
`flake.nixosSystemMap`, so colmena realises the **byte-identical closure**
`nixos-rebuild --flake .#<host>` does — verified by comparing `system.build.toplevel`
`drvPath`. Deploy targeting is `colmena apply --on <host>` or `--on @<tag>`.

## Considered Options

- **deploy-rs** — profile-based, with **auto-rollback if the target doesn't phone
  home** after activation. Genuinely valuable for the coming headless laptops (a
  bad config that kills networking reverts itself instead of a walk-over with a
  keyboard). Deferred, not rejected: colmena is lighter to stand up now, and
  migration later is a **one-file rewrite** (see the quarantine below), so we take
  the cheap tool first and switch when physical-access risk actually bites.
- **Stay hand-rolled (`nix run .#deploy`)** — a single generic app looping over
  `nixosConfigurations`. Zero new deps, but no tags, no parallelism, no rollback;
  doesn't scale to a tagged fleet. Rejected once host count > 1.
- **colmena at host #2 instead of now** — rejected. colmena-for-one-host is no
  heavier than the app it replaces, and standing up the hive now means adding a
  host later is a 4-line table entry, not learning colmena under pressure.
- **Per-node pkgs via `meta.nodeNixpkgs`** — rejected. Pinning `nixpkgs.pkgs`
  makes NixOS ignore each host's `nixpkgs.overlays`/`config`, silently dropping
  the repo's tree-sitter grammars + package pins from deployed hosts. Instead we
  set only `nixpkgs.hostPlatform` per node and let each host's `nix-settings`
  module apply overlays — identical to `mkNixos`.

## Consequences

- **Deploy metadata is quarantined to `modules/flake/colmena.nix`.** The
  `deployMeta` table (`targetHost`/`targetUser`/`tags`) and colmena's
  `deployment.*` options are the *only* colmena-specific coupling; host and
  (future) k3s role modules stay tool-agnostic. Migrating to deploy-rs later =
  rewrite this one file. `deployment.tags` must **not** be scattered into role
  modules — they wouldn't eval under `nixos-rebuild`/deploy-rs.
- **`makeHive` needs three things `nixpkgs.lib.nixosSystem` injects, replicated
  in the node** to keep the closure byte-identical (shared cache, no `pre-git`
  version label): `system.nixos.versionSuffix`, `system.nixos.revision`, and the
  `nix.registry.nixpkgs` pin.
- **`buildOnTarget = false`.** Builds on the deployer (tuxedo), substituting from
  the kasha cache and cross-building aarch64 via tuxedo's binfmt when uncached —
  today's behaviour. The RPi3 can't self-build.
- **Sudo needs a forwarded ssh-agent.** Elevation is `pam_ssh_agent_auth`, so
  `ForwardAgent yes` for the target must be set client-side (`~/.ssh/config`).
- **`flake.nixosSystemMap` is now a declared merging option** (in `lib.nix`) so
  the hive can read it; previously it was write-only freeform.
- **Adding a host to the deploy set** = one entry in `deployMeta`. The coming k3s
  nodes get role modules tagged `k3s`/`server`/`agent`/`gpu` so
  `colmena apply --on @agent` works.
