_: {
  flake.modules.nixos.laptop =
    {
      config,
      lib,
      ...
    }:
    {
      options.znix.laptop.enable = lib.mkEnableOption "laptop power and display management";

      config = lib.mkIf config.znix.laptop.enable {
        # powerManagement.powertop.enable = true;

        services = {
          upower.enable = true;
          power-profiles-daemon.enable = true;
          logind.settings.Login = {
            HandleLidSwitch = "suspend";
            HandleLidSwitchExternalPower = "lock";
            HandlePowerKey = "suspend";
            HandlePowerKeyLongPress = "poweroff";
          };
        };

        hardware.graphics.enable = true;
      };
    };
}
