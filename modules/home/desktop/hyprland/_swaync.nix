{
  config,
  lib,
  pkgs,
  ...
}:
let
  theme = builtins.fromJSON (builtins.readFile ./shell-theme.json);
in
lib.mkIf (config.znix.desktop.hyprland.shellPreset == "waybar-swaync") {
  home.packages = [ pkgs.swaynotificationcenter ];

  home.file.".config/swaync/config.json".text = builtins.toJSON {
    positionX = "right";
    positionY = "top";
    layer = "overlay";
    control-center-layer = "top";
    control-center-width = 420;
    control-center-height = 720;
    fit-to-screen = true;
    notification-window-width = 360;
    keyboard-shortcuts = true;
    image-visibility = "when-available";
    timeout = 5;
    timeout-low = 3;
    timeout-critical = 0;
    transition-time = 200;
    hide-on-clear = true;
    hide-on-action = true;
    widgets = [
      "title"
      "notifications"
      "mpris"
      "buttons-grid"
    ];
    widget-config = {
      title = {
        text = "Notifications";
        clear-all-button = true;
        button-text = "Clear";
      };
      mpris = {
        image-size = 64;
        image-radius = 8;
      };
      buttons-grid = {
        actions = [
          {
            label = "Bluetooth";
            command = "blueman-manager";
          }
          {
            label = "Audio";
            command = "pavucontrol";
          }
        ];
      };
    };
  };

  home.file.".config/swaync/style.css".text = ''
    * {
      font-family: "${theme.font.name}";
      font-size: ${toString theme.font.size}pt;
    }

    .control-center,
    .notification,
    .notification-content,
    .floating-notifications {
      background: alpha(${theme.colors.bg}, 0.95);
      color: ${theme.colors.fg};
      border: 1px solid ${theme.colors.bgStrong};
      border-radius: ${toString theme.radius}px;
    }

    .notification-default-action:hover,
    .widget-title button:hover,
    .widget-buttons-grid > flowbox > flowboxchild > button:hover {
      background: ${theme.colors.bgWeak};
    }

    .widget-title,
    .widget-title button,
    .widget-label,
    .widget-mpris {
      color: ${theme.colors.fg};
    }

    .notification.critical {
      border-color: ${theme.colors.danger};
    }

    .notification.low {
      border-color: ${theme.colors.bgStrong};
    }

    .notification.normal {
      border-color: ${theme.colors.accent};
    }
  '';

  systemd.user.services.swaync = {
    Unit = {
      Description = "Sway Notification Center";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStartPre = "-${pkgs.procps}/bin/pkill -x mako";
      ExecStart = "${lib.getExe pkgs.swaynotificationcenter} --config %h/.config/swaync/config.json --style %h/.config/swaync/style.css";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
