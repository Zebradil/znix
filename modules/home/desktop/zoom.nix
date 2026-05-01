_: {
  flake.modules.homeManager.zoom =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      base = {
        home.packages = with pkgs; [
          zoom-us
        ];
      };
      impermanence = lib.mkIf osConfig.znix.impermanence.enable {
        home.persistence."/persist".directories = [ ".config/zoomus" ];
      };
    in
    lib.mkMerge [
      base
      impermanence
    ];
}
