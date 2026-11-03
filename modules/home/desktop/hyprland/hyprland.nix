{ lib, ... }:
{
  flake-file.inputs = {
    ashell = {
      url = "github:MalpenZibo/ashell";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "rust-overlay";
    };
    # ashell's own lock pins a rust-overlay that trips nixpkgs'
    # `stdenv.isLinux` deprecation warning.
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
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
            b:
            let
              parts = lib.splitString " + " (builtins.head b._args);
              key = lib.toLower (lib.last parts);
            in
            lib.optional (cyrillicMap ? ${key}) (
              b
              // {
                _args = [
                  (lib.concatStringsSep " + " (lib.init parts ++ [ cyrillicMap.${key} ]))
                ]
                ++ builtins.tail b._args;
              }
            );
        in
        binds ++ lib.concatMap toCyrillic binds;
      hl = import ./_lua.nix { inherit lib; };
      inherit (hl) bind bindExec bindOpts;
      menu = "hypr-exec anyrun";
      terminal = "kitty";
      setLayout = layout: "function() hl.config({ general = { layout = \"${layout}\" } }) end";
      repeatLocked = bindOpts {
        repeating = true;
        locked = true;
      };
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
        pavucontrol
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
        configType = "lua";
        plugins = with pkgs; [
          # hyprlandPlugins.hyprbars
        ];
        settings.bind =
          withCyrillic [
            (bindExec "SUPER + Space" menu)

            (bind "SUPER + F" "hl.dsp.window.fullscreen()")
            (bind "SUPER + SHIFT + Q" "hl.dsp.window.close()")

            (bind "SUPER + SHIFT + F" "hl.dsp.window.float({ action = \"toggle\" })")
            (bindExec "SUPER + SHIFT + CTRL + L" "hypr-exec loginctl lock-session")

            (bindExec "SUPER + E" "hypr-exec ${terminal} -e yazi")

            # Focus movement
            (bind "SUPER + l" "hl.dsp.focus({ direction = \"left\" })")
            (bind "SUPER + h" "hl.dsp.focus({ direction = \"right\" })")
            (bind "SUPER + k" "hl.dsp.focus({ direction = \"up\" })")
            (bind "SUPER + j" "hl.dsp.focus({ direction = \"down\" })")
            # Window movement
            (bind "SUPER + SHIFT + l" "hl.dsp.window.move({ direction = \"left\" })")
            (bind "SUPER + SHIFT + h" "hl.dsp.window.move({ direction = \"right\" })")
            (bind "SUPER + SHIFT + k" "hl.dsp.window.move({ direction = \"up\" })")
            (bind "SUPER + SHIFT + j" "hl.dsp.window.move({ direction = \"down\" })")
          ]
          ++ [
            # Focus movement (arrow keys work across all layouts)
            (bind "SUPER + left" "hl.dsp.focus({ direction = \"left\" })")
            (bind "SUPER + right" "hl.dsp.focus({ direction = \"right\" })")
            (bind "SUPER + up" "hl.dsp.focus({ direction = \"up\" })")
            (bind "SUPER + down" "hl.dsp.focus({ direction = \"down\" })")
            # Window movement
            (bind "SUPER + SHIFT + left" "hl.dsp.window.move({ direction = \"left\" })")
            (bind "SUPER + SHIFT + right" "hl.dsp.window.move({ direction = \"right\" })")
            (bind "SUPER + SHIFT + up" "hl.dsp.window.move({ direction = \"up\" })")
            (bind "SUPER + SHIFT + down" "hl.dsp.window.move({ direction = \"down\" })")
            # Media playback
            (bindExec "XF86AudioPlay" "hypr-exec playerctl play-pause")
            (bindExec "XF86AudioNext" "hypr-exec playerctl next")
            (bindExec "XF86AudioPrev" "hypr-exec playerctl previous")
            (bindExec "XF86AudioStop" "hypr-exec playerctl stop")
            # Volume toggles (no repeat needed)
            (bindExec "XF86AudioMute" "hypr-exec swayosd-client --output-volume mute-toggle")
            (bindExec "XF86AudioMicMute" "hypr-exec swayosd-client --input-volume mute-toggle")
            # Layout switching
            (bind "SUPER + comma" (setLayout "master"))
            (bind "SUPER + period" (setLayout "dwindle"))
            # Repeat-on-hold bindings
            (repeatLocked "SUPER + XF86MonBrightnessUp" (hl.exec "kbd-brightness raise"))
            (repeatLocked "SUPER + XF86MonBrightnessDown" (hl.exec "kbd-brightness lower"))
            (repeatLocked "XF86MonBrightnessUp" (hl.exec "swayosd-client --brightness raise"))
            (repeatLocked "XF86MonBrightnessDown" (hl.exec "swayosd-client --brightness lower"))
            (repeatLocked "XF86AudioRaiseVolume" (hl.exec "swayosd-client --output-volume raise"))
            (repeatLocked "XF86AudioLowerVolume" (hl.exec "swayosd-client --output-volume lower"))
          ]
          ++ (
            # SUPER + [SHIFT +] {1..9} focuses [moves the window to] workspace {1..9}
            builtins.concatLists (
              builtins.genList (
                i:
                let
                  ws = toString (i + 1);
                in
                [
                  (bind "SUPER + code:1${toString i}" "hl.dsp.focus({ workspace = ${ws} })")
                  (bind "SUPER + SHIFT + code:1${toString i}" "hl.dsp.window.move({ workspace = ${ws} })")
                ]
              ) 9
            )
          );
      };
      # Hyprland writes a default hyprland.lua when it starts before activation
      # created the link; overwrite it instead of failing activation.
      xdg.configFile."hypr/hyprland.lua".force = true;
      services = {
        network-manager-applet.enable = true;
        blueman-applet.enable = true;
        udiskie = {
          enable = true;
          tray = "auto";
          automount = true;
          notify = true;
        };
      };
    };
}
