_: {
  flake.modules.homeManager.gh =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      base = {
        home.packages = [ pkgs.gh ];
      };
      impermanence = lib.mkIf config.znix.impermanence.enable {
        home.persistence."/persist".directories = [ ".config/gh" ];
      };
    in
    lib.mkMerge [
      base
      impermanence
    ];
}
