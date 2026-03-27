_: {
  flake.modules.homeManager.telegram =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        telegram-desktop
      ];

      # home.persistence."/persist" = lib.mkIf osConfig.znix.impermanence.enable {
      #   directories = [ ".config/TelegramDesktop" ];
      # };
    };
}
