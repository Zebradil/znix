{ inputs, ... }:
{
  flake-file.inputs.determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";

  flake.modules.nixos.determinate = {
    imports = [ inputs.determinate.nixosModules.default ];
  };

  flake.modules.darwin.determinate = {
    imports = [ inputs.determinate.darwinModules.default ];
  };
}
