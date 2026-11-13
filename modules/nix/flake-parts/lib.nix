{
  inputs,
  lib,
  ...
}:
let
  # znix's own workarounds always apply (its overlay through
  # overlays.default). A flake that passes itself as `flake` adds its own
  # class module and overlay on top.
  isConsumer = flake: flake.outPath != inputs.self.outPath;
  consumerOverlays =
    flake: lib.optional (isConsumer flake && flake ? overlays.workarounds) flake.overlays.workarounds;
  workaroundModules =
    class: flake:
    [
      inputs.self.modules.${class}.workarounds
      { nixpkgs.overlays = consumerOverlays flake; }
    ]
    ++ lib.optional (
      isConsumer flake && flake ? modules.${class}.workarounds
    ) flake.modules.${class}.workarounds;
in
{
  # Helper functions for creating system / home-manager configurations

  options.flake.lib = lib.mkOption {
    type = lib.types.attrsOf lib.types.unspecified;
    default = { };
  };

  # Declare homeConfigurations as a merging option so each host's
  # flake-parts.nix can contribute its own <user>@<host> key. flake-parts
  # leaves it in the non-merging freeform bucket otherwise, and two hosts
  # defining it collide ("Define the value only once").
  options.flake.homeConfigurations = lib.mkOption {
    type = lib.types.attrsOf lib.types.unspecified;
    default = { };
  };

  # host -> system map. Each host's flake-parts.nix contributes one key; it
  # stays in flake-parts' freeform bucket and can't be *read* (only written)
  # until declared as a merging option — the colmena hive reads it.
  options.flake.nixosSystemMap = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
  };

  # Consumed by mkDarwin below. Declared here rather than in a host module:
  # znix keeps no darwin host of its own, but exports the factory and the
  # darwin module set to flakes that do.
  config.flake-file.inputs.nix-darwin = {
    url = "github:LnL7/nix-darwin";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  config.flake.lib = {

    # `nixpkgs` lets a host pin its own nixpkgs input without dragging every
    # other host off unstable.
    # `flake` lets an external flake that takes znix as an input resolve the
    # host module from its own registry (pass its `self`) instead of znix's.
    mkNixos =
      system: name:
      {
        nixpkgs ? inputs.nixpkgs,
        flake ? inputs.self,
      }:
      {
        ${name} = nixpkgs.lib.nixosSystem {
          modules = [
            flake.modules.nixos.${name}
            { nixpkgs.hostPlatform = lib.mkDefault system; }
          ]
          ++ workaroundModules "nixos" flake;
        };
      };

    mkDarwin =
      system: name:
      {
        flake ? inputs.self,
      }:
      {
        ${name} = inputs.nix-darwin.lib.darwinSystem {
          modules = [
            flake.modules.darwin.${name}
            { nixpkgs.hostPlatform = lib.mkDefault system; }
          ]
          ++ workaroundModules "darwin" flake;
        };
      };

    # Standalone home-manager entrypoint (home-manager switch --flake .#<key>).
    # Unlike integrated home (useGlobalPkgs borrows the system's pkgs), this
    # builds its own pkgs, so it must replicate BOTH host-divergence knobs:
    #   - `nixpkgs`: the host's own input, when it pins one.
    #   - self.overlays.default: external packages + workarounds.
    # Omitting either would resolve files to different store paths than the
    # system switch. `standalone = true` flips the HM impermanence import.
    # `extraModules` lets an external flake sweep its own homeManager module
    # registry in on top of znix's (znix's set is always included); that sweep
    # also carries its homeManager.workarounds. `flake` adds that flake's
    # workarounds overlay, which nixpkgs.overlays cannot: pkgs is built here.
    mkHomeManager =
      system: key:
      {
        profile,
        nixpkgs ? inputs.nixpkgs,
        isDarwin ? false,
        excludeModules ? [ ],
        extraModules ? [ ],
        flake ? inputs.self,
      }:
      {
        ${key} = inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ inputs.self.overlays.default ] ++ consumerOverlays flake;
            config.allowUnfree = true;
          };
          extraSpecialArgs = {
            inherit inputs isDarwin;
            standalone = true;
          };
          modules =
            (builtins.attrValues (removeAttrs inputs.self.modules.homeManager excludeModules))
            ++ extraModules
            ++ [ profile ];
        };
      };

  };
}
