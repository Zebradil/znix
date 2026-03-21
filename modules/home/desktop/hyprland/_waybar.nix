{ pkgs, lib, ... }:

let
  commonDeps = with pkgs; [
    coreutils
    gnugrep
    systemd
  ];

  # Function to simplify making waybar outputs
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
  # Specialized for JSON outputs
  mkScriptJson =
    {
      name ? "script",
      deps ? [ ],
      script ? "",
      text ? "",
      tooltip ? "",
      alt ? "",
      class ? "",
      percentage ? "",
    }:
    mkScript {
      inherit name;
      deps = [ pkgs.jq ] ++ deps;
      script = ''
        ${script}
        jq -cn \
          --arg text "${text}" \
          --arg tooltip "${tooltip}" \
          --arg alt "${alt}" \
          --arg class "${class}" \
          --arg percentage "${percentage}" \
          '{text:$text,tooltip:$tooltip,alt:$alt,class:$class,percentage:$percentage}'
      '';
    };
in
{
  programs.waybar = {
    enable = true;
    systemd.enable = true;

    settings = {
      primary = {
        exclusive = false;
        passthrough = false;
        height = 40;
        margin = "6";
        position = "top";
        modules-left = [
          "custom/menu"
          "hyprland/workspaces"
          "hyprland/submap"
          "custom/currentplayer"
          "custom/player"
        ];

        modules-right = [
          "tray"
          "custom/gpg-status"
          "custom/sync-status"
          "custom/unread-mail"
          "custom/next-event"
          "network"
          "custom/rfkill"
          "battery"
          "pulseaudio"
          "clock"
        ];

        clock = {
          format = "{:%H:%M %d/%m}";
          on-click-left = "mode";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
        };

        cpu = {
          interval = 5;
          format = "  {usage}%";
        };
        "custom/gpu" = {
          interval = 5;
          exec = mkScript { script = "cat /sys/class/drm/card*/device/gpu_busy_percent | head -1"; };
          format = "󰒋  {}%";
        };
        memory = {
          format = "  {}%";
          interval = 5;
        };

        "pulseaudio" = {
          format = "{icon}{format_source}";
          format-bluetooth = "{icon} 󰂯{format_source}";
          format-source = "";
          format-source-muted = " 󰍭";
          format-icons = {
            default-muted = "󰸈";
            default = [
              "󰕿"
              "󰖀"
              "󰖀"
              "󰕾"
            ];
            headphone-muted = "󰟎";
            headphone = "󰋋";
            headset-muted = "󰋐";
            headset = "󰋎";
          };
          on-click = lib.getExe pkgs.pavucontrol;
        };
        idle_inhibitor = {
          format = "{icon}";
          format-icons = {
            activated = "󰒳";
            deactivated = "󰒲";
          };
        };
        battery = {
          interval = 10;
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
          format = "{icon}";
          format-charging = "󰂄";
          tooltip-format = "{capacity}% ({time})";
          onclick = "";
        };
        "sway/window" = {
          max-length = 20;
        };
        network = {
          interval = 3;
          format-wifi = "󰖩";
          format-ethernet = "󰈀";
          format-disconnected = "";
          tooltip-format = ''
            {essid}
            {ifname}
            {ipaddr}/{cidr}
            Up: {bandwidthUpBits}
            Down: {bandwidthDownBits}'';
        };
        "custom/menu" = {
          return-type = "json";
          exec = mkScriptJson {
            tooltip = "$USER@$HOSTNAME";
            alt = "$(grep LOGO /etc/os-release | cut -d = -f2 | cut -d '\"' -f2)";
          };
          format = "{icon}";
          format-icons = {
            "nix-snowflake" = "";
            "ubuntu-logo" = "󰕈";
          };
        };
        "custom/unread-mail" = {
          interval = 10;
          return-type = "json";
          exec = mkScriptJson {
            deps = [
              pkgs.findutils
              pkgs.gawk
            ];
            script = ''
              inbox_count="$(find ~/Mail/*/Inbox/new -type f | cut -d / -f5 | uniq -c | awk '{$1=$1};1')"
              if [ -z "$inbox_count" ]; then
                status="read"
                inbox_count="No new mail!"
              else
                status="unread"
              fi
            '';
            tooltip = "$inbox_count";
            alt = "$status";
          };
          format = "{icon}";
          format-icons = {
            "read" = "󰇯";
            "unread" = "󰇮";
          };
          on-click = mkScript {
            deps = [ pkgs.handlr-regex ];
            script = "handlr launch x-scheme-handler/mailto";
          };
        };
        "custom/currentplayer" = {
          interval = 2;
          return-type = "json";
          exec = mkScriptJson {
            deps = [ pkgs.playerctl ];
            script = ''
              all_players=$(playerctl -l 2>/dev/null)
              selected_player="$(playerctl status -f "{{playerName}}" 2>/dev/null || true)"
              clean_player="$(echo "$selected_player" | cut -d '.' -f1)"
            '';
            alt = "$clean_player";
            tooltip = "$all_players";
          };
          format = "{icon}{text}";
          format-icons = {
            "" = " ";
            "Celluloid" = "󰎁 ";
            "spotify" = "󰓇 ";
            "ncspot" = "󰓇 ";
            "qutebrowser" = "󰖟 ";
            "firefox" = " ";
            "discord" = " 󰙯 ";
            "sublimemusic" = " ";
            "kdeconnect" = "󰄡 ";
            "chromium" = " ";
          };
        };
        "custom/player" = {
          exec-if = mkScript {
            deps = [ pkgs.playerctl ];
            script = ''
              selected_player="$(playerctl status -f "{{playerName}}" 2>/dev/null || true)"
              playerctl status -p "$selected_player" 2>/dev/null
            '';
          };
          exec = mkScript {
            deps = [ pkgs.playerctl ];
            script = ''
              selected_player="$(playerctl status -f "{{playerName}}" 2>/dev/null || true)"
              playerctl metadata -p "$selected_player" \
                --format '{"text": "{{artist}} - {{title}}", "alt": "{{status}}", "tooltip": "{{artist}} - {{title}} ({{album}})"}' 2>/dev/null
            '';
          };
          return-type = "json";
          interval = 2;
          max-length = 30;
          format = "{icon} {text}";
          format-icons = {
            "Playing" = "󰐊";
            "Paused" = "󰏤 ";
            "Stopped" = "󰓛";
          };
          on-click = mkScript {
            deps = [ pkgs.playerctl ];
            script = "playerctl play-pause";
          };
        };
        "custom/rfkill" = {
          interval = 3;
          exec-if = mkScript {
            deps = [ pkgs.util-linux ];
            script = "rfkill list wifi | grep yes -q";
          };
          exec = "echo 󰀝";
        };
      };
    };
  };
}
