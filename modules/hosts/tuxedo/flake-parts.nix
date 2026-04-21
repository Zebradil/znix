{ inputs, ... }:
{
  flake.nixosConfigurations = inputs.self.lib.mkNixos "x86_64-linux" "tuxedo";
  flake.nixosSystemMap.tuxedo = "x86_64-linux";
}
