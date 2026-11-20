{ inputs, ... }:
{
  flake.nixosConfigurations = inputs.self.lib.mkNixos "x86_64-linux" "lenovo" { };
  flake.nixosSystemMap.lenovo = "x86_64-linux";
}
