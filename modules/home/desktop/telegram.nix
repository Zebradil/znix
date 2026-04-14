_: {
  flake.modules.homeManager.telegram =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      base = {
        home.packages = with pkgs; [
          telegram-desktop
        ];
      };
      impermanence = lib.mkIf osConfig.znix.impermanence.enable {
        home.persistence."/persist".directories = [ ".config/TelegramDesktop" ];
      };
    in
    lib.mkMerge [
      base
      impermanence
    ];
}
