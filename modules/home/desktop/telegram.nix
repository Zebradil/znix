_: {
  flake.modules.homeManager.telegram =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      base = {
        home.packages = with pkgs; [
          telegram-desktop
        ];
      };
      impermanence = lib.mkIf config.znix.impermanence.enable {
        home.persistence."/persist".directories = [ ".local/share/TelegramDesktop" ];
      };
    in
    lib.mkMerge [
      base
      impermanence
    ];
}
