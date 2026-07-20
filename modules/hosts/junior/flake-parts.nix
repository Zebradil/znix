{ inputs, ... }:
{
  flake.nixosConfigurations = inputs.self.lib.mkNixos "x86_64-linux" "junior" { };
  flake.nixosSystemMap.junior = "x86_64-linux";
}
