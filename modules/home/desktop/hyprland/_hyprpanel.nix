{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf (config.znix.desktop.hyprland.shellPreset == "hyprpanel") {
  home.packages = [ pkgs.hyprpanel ];

  home.file.".config/hyprpanel/config.json".text = builtins.toJSON {
    bar = {
      launcher = {
        autoDetectIcon = true;
      };
      workspaces = {
        showIcons = false;
        show_numbered = true;
      };
      windowtitle = {
        custom_title = false;
      };
      clock = {
        format = "%H:%M %d/%m";
      };
      battery = {
        label = true;
      };
      bluetooth = {
        label = true;
      };
      network = {
        label = true;
      };
      systray = {
        enable = true;
      };
      volume = {
        label = true;
      };
      layouts = {
        "0" = {
          left = [
            "workspaces"
            "windowtitle"
          ];
          middle = [ ];
          right = [
            "bluetooth"
            "network"
            "battery"
            "volume"
            "systray"
            "clock"
            "notifications"
          ];
        };
      };
    };
    menus = {
      bluetooth = {
        showBattery = true;
      };
    };
    notifications = {
      position = "top right";
      active_monitor = true;
    };
    wallpaper.enable = false;
    dummy = true;
    hyprpanel = {
      restartAgs = true;
      restartCommand = "hyprpanel -q; hyprpanel";
      useLazyLoading = true;
    };
  };

  # Upstream is archived, so keep this preset close to stock.
  systemd.user.services.hyprpanel = {
    Unit = {
      Description = "HyprPanel";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = lib.getExe pkgs.hyprpanel;
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
