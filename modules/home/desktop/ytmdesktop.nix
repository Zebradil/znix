_: {
  flake.modules.homeManager.ytmdesktop =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      base = {
        home.packages = with pkgs; [
          ytmdesktop
        ];
      };
      impermanence = lib.mkIf config.znix.impermanence.enable {
        home.persistence."/persist".directories = [ ".config/YouTube Music Desktop App" ];
      };
    in
    lib.mkMerge [
      base
      impermanence
    ];
}
