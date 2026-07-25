{
  inputs,
  lib,
  config,
  ...
}:
let
  inherit (inputs) self;

  # host -> system, the single source of truth used by `mkNixos`.
  systemMap = config.flake.nixosSystemMap;

  deployMeta = {
    toddler = {
      targetHost = "toddler";
      targetUser = "suok";
      tags = [ "appliance" ];
    };
    # k3s server. Tagged only "server" (not "k3s") so `apply --on @k3s` sweeps
    # the agent fleet without ever rolling the control plane by accident.
    junior = {
      targetHost = config.flake.nixosConfigurations.junior.config.znix.k3sNode.selfLan;
      targetUser = "suok";
      tags = [ "server" ];
    };
  }
  // lib.genAttrs [ "d1" "d2" "d3" ] (host: {
    targetHost =
      lib.removeSuffix "/24"
        config.flake.nixosConfigurations.${host}.config.znix.dualNet.address;
    targetUser = "suok";
    tags = [
      "k3s"
      "agent"
    ];
  });

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
      # Build on the deployer for better cache utilization. Also, the RPi3 can't self-build.
      buildOnTarget = lib.mkDefault false;
    };
  };
in
{
  flake-file.inputs.colmena = {
    url = "github:zhaofengli/colmena";
    inputs.nixpkgs.follows = "nixpkgs";
  };

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
