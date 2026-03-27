{ inputs, ... }:
{
  flake-file.inputs.nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

  flake.modules.darwin.homebrew = _: {
    imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

    homebrew = {
      enable = true;
      onActivation.autoUpdate = true;
      brews = [ "displayplacer" ];
      casks = [
        "flameshot"
        "notunes"
        "orbstack"
        "orcaslicer"
      ];
    };
  };
}
