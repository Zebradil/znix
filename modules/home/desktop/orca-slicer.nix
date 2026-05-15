_: {
  flake.modules.homeManager.orca-slicer =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      base = {
        home.packages = with pkgs; [
          orca-slicer
        ];
      };
      impermanence = lib.mkIf osConfig.znix.impermanence.enable {
        home.persistence."/persist".directories = [ ".config/OrcaSlicer" ];
      };
    in
    lib.mkMerge [
      base
      impermanence
    ];
}
