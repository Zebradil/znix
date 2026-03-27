_: {
  flake.modules.nixos.locale =
    { lib, ... }:
    {
      i18n = {
        defaultLocale = lib.mkDefault "en_US.UTF-8";
        extraLocaleSettings = {
          LC_TIME = lib.mkDefault "en_DK.UTF-8";
        };
        extraLocales = [
          "de_DE.UTF-8/UTF-8"
          "en_DK.UTF-8/UTF-8"
        ];
      };
      location.provider = "geoclue2";
      time.timeZone = lib.mkDefault "Europe/Berlin";
      services.automatic-timezoned.enable = true;
    };
}
