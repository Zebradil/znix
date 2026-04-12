_: {
  flake.modules.nixos.laptop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.znix.laptop.enable = lib.mkEnableOption "laptop power and display management";

      config = lib.mkIf config.znix.laptop.enable {
        powerManagement.powertop.enable = true;

        services.upower.enable = true;
        # No use with tuxedo-rs
        # services.power-profiles-daemon.enable = true;

        environment.systemPackages = [ pkgs.brightnessctl ];

        services.logind.settings.Login = {
          HandleLidSwitch = "suspend";
          HandleLidSwitchExternalPower = "lock";
          HandlePowerKey = "suspend";
          HandlePowerKeyLongPress = "poweroff";
        };

        hardware.graphics.enable = true;
      };
    };
}
