{ inputs, ... }:
{
  flake-file.inputs.home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.modules.nixos.home-manager = {
    imports = [ inputs.home-manager.nixosModules.home-manager ];
    home-manager.extraSpecialArgs = {
      isDarwin = false;
    };
  };
  flake.modules.darwin.home-manager = {
    imports = [ inputs.home-manager.darwinModules.home-manager ];
    home-manager.extraSpecialArgs = {
      isDarwin = true;
    };
  };
}
