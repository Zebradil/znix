{ inputs, ... }:
{
  flake.nixosConfigurations = inputs.self.lib.mkNixos "x86_64-linux" "daddy" { };
  flake.nixosSystemMap.daddy = "x86_64-linux";
}
