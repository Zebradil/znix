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
        ./_ashell.nix
        ./_hyprlock.nix
        ./_hypridle.nix
        ./_hyprpaper.nix
        ./_screenshot.nix
        ./_mako.nix
      ];
      home.packages = with pkgs; [ playerctl ];
      wayland.windowManager.hyprland = {
        enable = true;
        plugins = with pkgs; [
          # hyprlandPlugins.hyprbars
        ];
        settings = {
          "$menu" = "hyprlauncher";
          "$terminal" = "kitty";
          "$browser" = "firefox";

          "$mod" = "SUPER";
          bind =
            withCyrillic [
              "$mod, Space, exec, $menu"

              "$mod, F, exec, fullscreen"
              "$mod, Q, exec, killactive"

              "$mod SHIFT, F, togglefloating"
              "$mod, L, exec, loginctl lock-session"
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
              ", XF86AudioPlay, exec, playerctl play-pause"
              ", XF86AudioNext, exec, playerctl next"
              ", XF86AudioPrev, exec, playerctl previous"
              ", XF86AudioStop, exec, playerctl stop"
              # Volume toggles (no repeat needed)
              ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
              ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
              # Layout switching
              "$mod, comma, exec, hyprctl keyword general:layout master"
              "$mod, period, exec, hyprctl keyword general:layout dwindle"
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
          binde = [
            ", XF86MonBrightnessUp, exec, brightnessctl set +5%"
            ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
            ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
            ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
          ];
        };
      };
      services = {
        hyprpolkitagent.enable = true;
        hyprlauncher.enable = true;
        network-manager-applet.enable = true;
      };
    };
}
