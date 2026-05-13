_: {
  flake.modules.homeManager.moonlight =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      base = {
        home.packages = with pkgs; [
          moonlight-qt
        ];
      };
      impermanence = lib.mkIf osConfig.znix.impermanence.enable {
        home.persistence."/persist".directories = [ ".config/Moonlight Game Streaming Project" ];
      };
    in
    lib.mkMerge [
      base
      impermanence
    ];
}
