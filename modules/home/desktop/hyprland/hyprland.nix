{ lib, ... }:
{
  flake-file.inputs = {
    ashell = {
      url = "github:MalpenZibo/ashell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  flake.modules.homeManager.hyprland =
    { pkgs, isDarwin, ... }:
    let
      # Dvorak key -> Cyrillic keysym mapping for ru(phonetic_dvorak)
      cyrillicMap = {
        a = "Cyrillic_a";
        b = "Cyrillic_be";
        c = "Cyrillic_tse";
        d = "Cyrillic_de";
        e = "Cyrillic_ie";
        f = "Cyrillic_ef";
        g = "Cyrillic_ghe";
        h = "Cyrillic_ha";
        i = "Cyrillic_i";
        j = "Cyrillic_shorti";
        k = "Cyrillic_ka";
        l = "Cyrillic_el";
        m = "Cyrillic_em";
        n = "Cyrillic_en";
        o = "Cyrillic_o";
        p = "Cyrillic_pe";
        q = "Cyrillic_ya";
        r = "Cyrillic_er";
        s = "Cyrillic_es";
        t = "Cyrillic_te";
        u = "Cyrillic_u";
        v = "Cyrillic_zhe";
        w = "Cyrillic_ve";
        x = "Cyrillic_softsign";
        y = "Cyrillic_yeru";
        z = "Cyrillic_ze";
      };
      # Wraps a bind list with Cyrillic duplicates for any single-letter key binds.
      # Non-letter keys (Space, code:XX, etc.) are skipped automatically.
      withCyrillic =
        binds:
        let
          toCyrillic =
            s:
            let
              parts = lib.splitString "," s;
              key = lib.toLower (lib.trim (builtins.elemAt parts 1));
              rest = builtins.tail (builtins.tail parts);
            in
            if builtins.length parts >= 3 && cyrillicMap ? ${key} then
              [
                (lib.concatStringsSep "," (
                  [
                    (builtins.head parts)
                    (" " + cyrillicMap.${key})
                  ]
                  ++ rest
                ))
              ]
            else
              [ ];
        in
        binds ++ lib.concatMap toCyrillic binds;
    in
    lib.optionalAttrs (!isDarwin) {
      imports = [
        ./_appearance.nix
        ./_input.nix
        ./_anyrun.nix
        ./_ashell.nix
        ./_hyprlock.nix
        ./_hypridle.nix
        ./_hyprpaper.nix
        ./_monitors.nix
        ./_screenshot.nix
        ./_mako.nix
        ./_swayosd.nix
      ];
      home.packages = with pkgs; [
        playerctl
        # Wrapper for hyprland exec bindings: captures stderr, appends failures
        # to a persistent session log, and pops a notification.
        # Log: $XDG_STATE_HOME/hyprland/hypr-exec.log  (default ~/.local/state/...)
        # Usage: hypr-exec <command> [args...]
        (writeShellApplication {
          name = "hypr-exec";
          runtimeInputs = [ libnotify ];
          text = ''
            log_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/hyprland"
            log_file="$log_dir/hypr-exec.log"
            mkdir -p "$log_dir"

            tmpfile=$(mktemp)
            exit_code=0
            SHLVL=0 "$@" 2>"$tmpfile" || exit_code=$?

            if [ "$exit_code" -ne 0 ]; then
              {
                printf '=== %s | exit %d ===\nCMD: %s\n' \
                  "$(date -Iseconds)" "$exit_code" "$(printf '%q ' "$@")"
                cat "$tmpfile"
                printf '\n'
              } >> "$log_file"
              notify-send -u critical "Exec failed" \
                "$(printf '%q ' "$@")\n\nExit: $exit_code — see $log_file"
            fi
            rm -f "$tmpfile"
            exit "$exit_code"
          '';
        })
        (writeShellApplication {
          name = "kbd-brightness";
          runtimeInputs = [
            brightnessctl
            gawk
            swayosd
          ];
          text = ''
            direction="$1"
            if [ "$direction" = "raise" ]; then
              brightnessctl --device='*kbd_backlight*' set +5%
            else
              brightnessctl --device='*kbd_backlight*' set 5%-
            fi
            val=$(brightnessctl --device='*kbd_backlight*' get)
            max=$(brightnessctl --device='*kbd_backlight*' max)
            progress=$(awk "BEGIN{printf \"%.2f\", $val/$max}")
            swayosd-client --custom-progress "$progress" --custom-icon keyboard-brightness-symbolic
          '';
        })
      ];
      wayland.windowManager.hyprland = {
        enable = true;
        plugins = with pkgs; [
          # hyprlandPlugins.hyprbars
        ];
        settings = {
          "$menu" = "hypr-exec anyrun";
          "$terminal" = "kitty";
          "$browser" = "firefox";

          "$mod" = "SUPER";
          bind =
            withCyrillic [
              "$mod, Space, exec, $menu"

              "$mod SHIFT, F, fullscreen"
              "$mod SHIFT, Q, killactive"

              "$mod SHIFT, F, togglefloating"
              "$mod, L, exec, hypr-exec loginctl lock-session"
            ]
            ++ [
              # Focus movement (arrow keys work across all layouts)
              "$mod, left, movefocus, l"
              "$mod, right, movefocus, r"
              "$mod, up, movefocus, u"
              "$mod, down, movefocus, d"
              # Window movement
              "$mod SHIFT, left, movewindow, l"
              "$mod SHIFT, right, movewindow, r"
              "$mod SHIFT, up, movewindow, u"
              "$mod SHIFT, down, movewindow, d"
              # Media playback
              ", XF86AudioPlay, exec, hypr-exec playerctl play-pause"
              ", XF86AudioNext, exec, hypr-exec playerctl next"
              ", XF86AudioPrev, exec, hypr-exec playerctl previous"
              ", XF86AudioStop, exec, hypr-exec playerctl stop"
              # Volume toggles (no repeat needed)
              ", XF86AudioMute, exec, hypr-exec swayosd-client --output-volume mute-toggle"
              ", XF86AudioMicMute, exec, hypr-exec swayosd-client --input-volume mute-toggle"
              # Layout switching
              "$mod, comma, exec, hypr-exec hyprctl keyword general:layout master"
              "$mod, period, exec, hypr-exec hyprctl keyword general:layout dwindle"
            ]
            ++ (
              # workspaces
              # binds $mod + [shift +] {1..9} to [move to] workspace {1..9}
              builtins.concatLists (
                builtins.genList (
                  i:
                  let
                    ws = i + 1;
                  in
                  [
                    "$mod, code:1${toString i}, workspace, ${toString ws}"
                    "$mod SHIFT, code:1${toString i}, movetoworkspace, ${toString ws}"
                  ]
                ) 9
              )
            );
          # Repeat-on-hold bindings
          bindel = [
            "$mod, XF86MonBrightnessUp, exec, kbd-brightness raise"
            "$mod, XF86MonBrightnessDown, exec, kbd-brightness lower"
            ", XF86MonBrightnessUp, exec, swayosd-client --brightness raise"
            ", XF86MonBrightnessDown, exec, swayosd-client --brightness lower"
            ", XF86AudioRaiseVolume, exec, swayosd-client --output-volume raise"
            ", XF86AudioLowerVolume, exec, swayosd-client --output-volume lower"
          ];
        };
      };
      services = {
        hyprpolkitagent.enable = true;
        network-manager-applet.enable = true;
        blueman-applet.enable = true;
      };
    };
}
