{
  config,
  lib,
  pkgs,
  ...
}:

let
  theme = builtins.fromJSON (builtins.readFile ./shell-theme.json);

  commonDeps = with pkgs; [
    coreutils
    gnugrep
    systemd
  ];

  mkScript =
    {
      name ? "script",
      deps ? [ ],
      script ? "",
    }:
    lib.getExe (
      pkgs.writeShellApplication {
        inherit name;
        text = script;
        runtimeInputs = commonDeps ++ deps;
      }
    );
in
lib.mkIf (config.znix.desktop.hyprland.shellPreset == "waybar-swaync") {
  programs.waybar = {
    enable = true;
    systemd.enable = true;

    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: "${theme.font.name}";
        font-size: ${toString theme.font.size}pt;
        min-height: 0;
      }

      window#waybar {
        background: transparent;
        color: ${theme.colors.fg};
      }

      .modules-left,
      .modules-center,
      .modules-right {
        margin: ${toString theme.margin}px;
        padding: 0 6px;
        background: alpha(${theme.colors.bg}, 0.92);
        border: 1px solid ${theme.colors.bgStrong};
        border-radius: ${toString theme.radius}px;
      }

      #workspaces button,
      #tray,
      #network,
      #pulseaudio,
      #battery,
      #clock,
      #custom-bluetooth,
      #window {
        margin: 0 4px;
        padding: 0 8px;
        color: ${theme.colors.fg};
      }

      #workspaces button.active {
        background: ${theme.colors.accent};
        color: ${theme.colors.bg};
        border-radius: ${toString theme.radius}px;
      }

      #battery.warning,
      #custom-bluetooth.off {
        color: ${theme.colors.warning};
      }

      #battery.critical {
        color: ${theme.colors.danger};
      }
    '';

    settings = {
      primary = {
        exclusive = true;
        layer = "top";
        passthrough = false;
        height = theme.barHeight;
        margin = toString theme.margin;
        position = "top";

        modules-left = [
          "hyprland/workspaces"
          "hyprland/window"
        ];

        modules-right = [
          "tray"
          "network"
          "custom/bluetooth"
          "battery"
          "pulseaudio"
          "clock"
        ];

        "hyprland/workspaces" = {
          disable-scroll = true;
          all-outputs = false;
        };

        "hyprland/window" = {
          max-length = 80;
          separate-outputs = true;
        };

        tray = {
          icon-size = 16;
          spacing = 8;
        };

        clock = {
          format = "{:%H:%M %d/%m}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
        };

        network = {
          format-wifi = "󰖩 {signalStrength}%";
          format-ethernet = "󰈀 {ifname}";
          format-disconnected = "󰖪";
          tooltip-format = ''
            {ifname}
            {ipaddr}/{cidr}
            Up: {bandwidthUpBits}
            Down: {bandwidthDownBits}'';
        };

        battery = {
          interval = 10;
          states = {
            warning = 25;
            critical = 10;
          };
          format = "{icon} {capacity}%";
          format-charging = "󰂄 {capacity}%";
          format-icons = [
            "󰁺"
            "󰁻"
            "󰁼"
            "󰁽"
            "󰁾"
            "󰁿"
            "󰂀"
            "󰂁"
            "󰂂"
            "󰁹"
          ];
          tooltip-format = "{capacity}% ({time})";
        };

        pulseaudio = {
          format = "{icon} {volume}%";
          format-muted = "󰸈 muted";
          format-bluetooth = "{icon} 󰂯 {volume}%";
          format-icons = {
            default = [
              "󰕿"
              "󰖀"
              "󰕾"
            ];
            headphone = "󰋋";
            headset = "󰋎";
          };
          on-click = lib.getExe pkgs.pavucontrol;
        };

        "custom/bluetooth" = {
          return-type = "json";
          interval = 5;
          exec = mkScript {
            name = "waybar-bluetooth";
            deps = [
              pkgs.bluez
              pkgs.gnused
              pkgs.gawk
              pkgs.jq
            ];
            script = ''
              if ! bluetoothctl show >/dev/null 2>&1; then
                jq -cn --arg text "󰂲" --arg tooltip "Bluetooth unavailable" --arg class "off" '{text:$text,tooltip:$tooltip,class:$class}'
                exit 0
              fi

              powered=$(bluetoothctl show | sed -n 's/^\s*Powered: //p')
              connected=$(bluetoothctl devices Connected | awk '{$1=$2=""; sub(/^  */, ""); print}' | paste -sd ', ' -)

              if [ "$powered" = "yes" ]; then
                if [ -n "$connected" ]; then
                  jq -cn --arg text "󰂱" --arg tooltip "$connected" --arg class "on" '{text:$text,tooltip:$tooltip,class:$class}'
                else
                  jq -cn --arg text "󰂯" --arg tooltip "Bluetooth on" --arg class "on" '{text:$text,tooltip:$tooltip,class:$class}'
                fi
              else
                jq -cn --arg text "󰂲" --arg tooltip "Bluetooth off" --arg class "off" '{text:$text,tooltip:$tooltip,class:$class}'
              fi
            '';
          };
          on-click = "blueman-manager";
          format = "{}";
        };
      };
    };
  };
}
