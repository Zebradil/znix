_: {
  flake.modules.homeManager.moonlight =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      base = {
        home.packages = with pkgs; [
          moonlight-qt
        ];
      };
      impermanence = lib.mkIf config.znix.impermanence.enable {
        home.persistence."/persist".directories = [ ".config/Moonlight Game Streaming Project" ];
      };
    in
    lib.mkMerge [
      base
      impermanence
    ];
}
