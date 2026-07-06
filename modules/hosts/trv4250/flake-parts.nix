{ inputs, ... }:
{
  flake-file.inputs.nix-darwin = {
    url = "github:LnL7/nix-darwin";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.darwinConfigurations = inputs.self.lib.mkDarwin "aarch64-darwin" "trv4250";
  flake.darwinSystemMap.trv4250 = "aarch64-darwin";

  # Standalone home for glashevich@trv4250. Drops the Linux-only GUI apps, same
  # as the integrated darwin sweep (see users/glashevich/default.nix).
  flake.homeConfigurations = inputs.self.lib.mkHomeManager "aarch64-darwin" "glashevich@trv4250" {
    profile = inputs.self.modules.generic.home-glashevich;
    isDarwin = true;
    excludeModules = [
      "firefox"
      "telegram"
      "slack"
    ];
  };
}
