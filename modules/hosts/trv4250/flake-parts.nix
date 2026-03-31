{ inputs, ... }:
{
  flake-file.inputs = {
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
  };

  flake.darwinConfigurations = inputs.self.lib.mkDarwin "aarch64-darwin" "trv4250";
}
