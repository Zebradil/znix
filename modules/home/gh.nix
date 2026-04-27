_: {
  flake.modules.homeManager.gh =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      base = {
        home.packages = [ pkgs.gh ];
      };
      impermanence = lib.mkIf osConfig.znix.impermanence.enable {
        home.persistence."/persist".directories = [ ".config/gh" ];
      };
    in
    lib.mkMerge [
      base
      impermanence
    ];
}
