{ inputs, ... }:
{
  flake.nixosConfigurations = inputs.self.lib.mkNixos "aarch64-linux" "toddler" { };
  flake.nixosSystemMap.toddler = "aarch64-linux";
}
