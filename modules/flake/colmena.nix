{
  inputs,
  lib,
  config,
  ...
}:
let
  self = inputs.self;

  # host -> system, the single source of truth already used by `mkNixos`.
  systemMap = config.flake.nixosSystemMap;

  # Deploy metadata is the ONLY colmena-specific coupling in the repo. Kept
  # here, deliberately OUT of the host/role modules, so migrating to deploy-rs
  # later is a one-file rewrite — host and (future) k3s role modules stay
  # tool-agnostic. Tag vocabulary: `appliance` for one-offs; reserve
  # `k3s`/`server`/`agent`/`gpu` for the coming fleet so `--on @agent` works.
  deployMeta = {
    toddler = {
      targetHost = "toddler";
      targetUser = "suok";
      tags = [ "appliance" ];
    };
  };

  # A hive node reuses the exact module set `mkNixos` builds
  # (`self.modules.nixos.<host>` + hostPlatform), so colmena realises the same
  # closure `nixos-rebuild --flake .#<host>` does — no config duplication.
  # `deployment.*` exists only inside `makeHive`'s eval (colmena injects it),
  # which is what keeps this coupling quarantined to this file.
  mkNode = host: meta: {
    imports = [ self.modules.nixos.${host} ];
    nixpkgs.hostPlatform = lib.mkDefault systemMap.${host};
    # `makeHive` evaluates raw eval-config and, unlike `nixpkgs.lib.nixosSystem`,
    # does NOT stamp the flake's nixpkgs revision into the system version. Inject
    # it so colmena realises the byte-identical closure `nixos-rebuild` does
    # (shared cache, stable version label) instead of a `pre-git` divergence.
    system.nixos.versionSuffix = ".${
      builtins.substring 0 8 (
        inputs.nixpkgs.lastModifiedDate or inputs.nixpkgs.lastModified or "19700101"
      )
    }.${inputs.nixpkgs.shortRev or "dirty"}";
    system.nixos.revision = inputs.nixpkgs.rev or "dirty";
    # `nixpkgs.lib.nixosSystem` also pins the `nixpkgs` flake registry entry;
    # `makeHive` skips it (nix-settings deliberately excludes nixpkgs from its
    # own registry map). Add it back so the closure matches byte-for-byte.
    nix.registry.nixpkgs.to = {
      type = "path";
      path = inputs.nixpkgs.outPath;
    };
    deployment = {
      inherit (meta) targetHost targetUser tags;
      # Build on the deployer (tuxedo), substituting from the kasha cache and
      # cross-building via tuxedo's aarch64 binfmt when a path is uncached —
      # exactly today's `deploy-toddler` behaviour. The RPi3 can't self-build.
      buildOnTarget = lib.mkDefault false;
    };
  };
in
{
  flake-file.inputs.colmena = {
    url = "github:zhaofengli/colmena";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # `colmena apply --on toddler` (or `--on @appliance`). Colmena reads the
  # `colmenaHive` output; `meta.nixpkgs` seeds lib + the default (x86) pkgs.
  # Per-node arch comes from each node's `nixpkgs.hostPlatform`, and overlays
  # (tree-sitter grammars + pins) come from each host's own `nix-settings`
  # module — so meta carries no overlays, avoiding a pkgs-pinning conflict.
  flake.colmenaHive = inputs.colmena.lib.makeHive (
    {
      meta.nixpkgs = import inputs.nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
    }
    // lib.mapAttrs mkNode deployMeta
  );
}
