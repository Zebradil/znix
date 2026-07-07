{
  inputs,
  lib,
  ...
}:
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

  config.flake.lib = {

    # `nixpkgs` lets a host pin its own nixpkgs input (e.g. tuxedo stays on a
    # known-good GDM rev) without dragging every other host off unstable.
    mkNixos =
      system: name:
      {
        nixpkgs ? inputs.nixpkgs,
      }:
      {
        ${name} = nixpkgs.lib.nixosSystem {
          modules = [
            inputs.self.modules.nixos.${name}
            { nixpkgs.hostPlatform = lib.mkDefault system; }
          ];
        };
      };

    mkDarwin = system: name: {
      ${name} = inputs.nix-darwin.lib.darwinSystem {
        modules = [
          inputs.self.modules.darwin.${name}
          { nixpkgs.hostPlatform = lib.mkDefault system; }
        ];
      };
    };

    # Standalone home-manager entrypoint (home-manager switch --flake .#<key>).
    # Unlike integrated home (useGlobalPkgs borrows the system's pkgs), this
    # builds its own pkgs, so it must replicate BOTH host-divergence knobs:
    #   - `nixpkgs`: the host's own input (tuxedo pins nixpkgs-tuxedo for GDM).
    #   - self.overlays.default: tree-sitter grammars + package pins.
    # Omitting either would resolve files to different store paths than the
    # system switch. `standalone = true` flips the HM impermanence import.
    mkHomeManager =
      system: key:
      {
        profile,
        nixpkgs ? inputs.nixpkgs,
        isDarwin ? false,
        excludeModules ? [ ],
      }:
      {
        ${key} = inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ inputs.self.overlays.default ];
            config.allowUnfree = true;
          };
          extraSpecialArgs = {
            inherit inputs isDarwin;
            standalone = true;
          };
          modules = (builtins.attrValues (removeAttrs inputs.self.modules.homeManager excludeModules)) ++ [
            profile
          ];
        };
      };

  };
}
