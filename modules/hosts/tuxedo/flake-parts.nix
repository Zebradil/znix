{ inputs, ... }:
{
  flake.nixosConfigurations = inputs.self.lib.mkNixos "x86_64-linux" "tuxedo" { };
  flake.nixosSystemMap.tuxedo = "x86_64-linux";

  # Standalone home for zebradil@tuxedo.
  flake.homeConfigurations = inputs.self.lib.mkHomeManager "x86_64-linux" "zebradil@tuxedo" {
    profile = inputs.self.modules.generic.home-zebradil;
  };
}
