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
        home.packages = [
          pkgs.diffnav
          pkgs.gh
          pkgs.gh-dash
          pkgs.gh-enhance
        ];
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
