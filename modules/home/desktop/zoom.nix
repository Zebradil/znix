_: {
  flake.modules.homeManager.zoom =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      base = {
        home.packages = with pkgs; [
          zoom-us
        ];
      };
      impermanence = lib.mkIf config.znix.impermanence.enable {
        home.persistence."/persist".directories = [ ".config/zoomus" ];
      };
    in
    lib.mkMerge [
      base
      impermanence
    ];
}
