_: {
  flake.modules.nixos.laptop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Disable USB autosuspend for Dell dock Realtek hubs by vendor:product ID.
      dockUsbFixScript = pkgs.writeShellScript "dock-usb-autosuspend-off" ''
        for dev in /sys/bus/usb/devices/*; do
          vendor="$(cat "$dev/idVendor" 2>/dev/null)" || continue
          product="$(cat "$dev/idProduct" 2>/dev/null)" || continue
          case "$vendor:$product" in
            0bda:5487|0bda:5413)
              echo on > "$dev/power/control" 2>/dev/null || true
              ;;
          esac
        done
      '';
    in
    {
      options.znix.laptop.enable = lib.mkEnableOption "laptop power and display management";

      config = lib.mkIf config.znix.laptop.enable {
        powerManagement.powertop.enable = true;

        # Disable USB autosuspend for Dell dock hubs (Realtek).
        # powertop --auto-tune enables autosuspend on all USB devices, but
        # these dock hubs don't handle suspend properly, causing disconnect storms.
        # Use RUN+= (not ATTR=) to reliably write after device is fully initialized.
        services.udev.extraRules = ''
          ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", ATTR{idProduct}=="5487", RUN+="${dockUsbFixScript}"
          ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", ATTR{idProduct}=="5413", RUN+="${dockUsbFixScript}"
        '';

        # Also override powertop's USB settings at boot for already-connected docks
        systemd.services.dock-usb-autosuspend-off = {
          description = "Disable USB autosuspend for Dell dock hubs";
          after = [ "powertop.service" ];
          wants = [ "powertop.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = dockUsbFixScript;
          };
        };

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
