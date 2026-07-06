{ inputs, ... }:
{
  flake-file.inputs.home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.modules.nixos.home-manager = {
    imports = [ inputs.home-manager.nixosModules.home-manager ];
    home-manager.extraSpecialArgs = {
      inherit inputs;
      isDarwin = false;
      # Integrated mode: home.persistence comes from the NixOS impermanence
      # module's sharedModules injection, so home modules must NOT import the
      # HM impermanence module themselves. Standalone flips this (see mkHomeManager).
      standalone = false;
    };
  };
  flake.modules.darwin.home-manager = {
    imports = [ inputs.home-manager.darwinModules.home-manager ];
    home-manager.extraSpecialArgs = {
      inherit inputs;
      isDarwin = true;
      standalone = false;
    };
  };
}
