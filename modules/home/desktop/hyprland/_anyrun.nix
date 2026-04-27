{ inputs, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  anyrunPkgs = inputs.anyrun.packages.${system};
  anyrunBin = "${anyrunPkgs.anyrun}/bin/anyrun";
  stdinLib = "${anyrunPkgs.stdin}/lib/libstdin.so";

  # Shared CSS — applied both to the main launcher and the picker overlay.
  # Explicit resets instead of `all: unset` to avoid breaking GTK4 internals.
  css = /* css */ ''
    * {
      font-family: "IosevkaTerm Nerd Font", monospace;
      font-size: 14px;
      color: #cdd6f4;
      background: transparent;
      border: none;
      margin: 0;
      padding: 0;
    }

    #window,
    #overlay {
      background: transparent;
    }

    #main {
      background: #1e1e2e;
      border: 1px solid #45475a;
      border-radius: 12px;
      padding: 8px;
      box-shadow: 0 8px 32px rgba(0,0,0,0.7);
    }

    entry {
      background: #313244;
      border-radius: 8px;
      padding: 8px 12px;
      margin-bottom: 4px;
    }

    entry:focus {
      border: 1px solid #cba6f7;
    }

    #plugin {
      color: #6c7086;
      font-size: 12px;
      padding: 2px 8px;
    }

    row {
      border-radius: 8px;
      padding: 4px 8px;
    }

    row:selected,
    row:hover {
      background: #313244;
    }
  '';

  wifi-picker = pkgs.writeShellApplication {
    name = "wifi-picker";
    runtimeInputs = with pkgs; [
      networkmanager
      libnotify
    ];
    text = ''
      networks=$(nmcli -t -f SSID,SIGNAL,SECURITY device wifi list --rescan yes 2>/dev/null \
        | sort -t: -k2 -rn \
        | awk -F: 'NF>=3 && $1 != "" {
            gsub(/\\:/, ":", $1)
            printf "%s (%s%%, %s)\n", $1, $2, $3
          }' \
        | awk '!seen[$0]++')

      if [ -z "$networks" ]; then
        notify-send -u critical "WiFi" "No networks found"
        exit 1
      fi

      chosen=$(printf '%s\n' "$networks" | ${anyrunBin} --plugins "${stdinLib}" --show_results_immediately true)
      [ -z "$chosen" ] && exit 0

      ssid="''${chosen%% (*}"
      nmcli device wifi connect "$ssid" && notify-send "WiFi" "Connected to $ssid"
    '';
  };

  perf-picker = pkgs.writeShellApplication {
    name = "perf-picker";
    runtimeInputs = with pkgs; [
      power-profiles-daemon
      libnotify
    ];
    text = ''
            current=$(powerprofilesctl get)
            options=""
            while IFS= read -r profile; do
              if [ "$profile" = "$current" ]; then
                options="''${options}* $profile
      "
              else
                options="''${options}$profile
      "
              fi
            done < <(powerprofilesctl list \
              | sed -n 's/^[[:space:]]*\*\?[[:space:]]*\([a-z-]*\):$/\1/p')

            chosen=$(printf '%s' "$options" | ${anyrunBin} --plugins "${stdinLib}" --show_results_immediately true)
            [ -z "$chosen" ] && exit 0
            chosen="''${chosen#\* }"
            powerprofilesctl set "$chosen"
            notify-send "Performance" "Profile: $chosen"
    '';
  };
in
{
  programs.anyrun = {
    enable = true;
    package = anyrunPkgs.anyrun;
    config = {
      plugins = with anyrunPkgs; [
        applications
        symbols
        rink
      ];
      width.fraction = 0.3;
      y.fraction = 0.2;
      hidePluginInfo = true;
      closeOnClick = true;
    };
    # extraCss = css;
  };

  home.packages = [
    wifi-picker
    perf-picker
  ];

  wayland.windowManager.hyprland.settings.bind = [
    "$mod SHIFT, W, exec, hypr-exec wifi-picker"
    "$mod SHIFT, P, exec, hypr-exec perf-picker"
  ];
}
