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
      imports = [ ./_ashell.nix ];
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
          input = {
            kb_layout = "us,us,ru";
            kb_variant = ",dvorak,phonetic_dvorak";
            kb_options = "grp:caps_toggle";
            resolve_binds_by_sym = true;
          };
          bind =
            withCyrillic [
              "$mod, Space, exec, $menu"

              "$mod, F, exec, $browser"
              "$mod, Q, exec, $terminal"
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
        };
      };
      services.hyprlauncher = {
        enable = true;
      };
      services.network-manager-applet.enable = true;
    };
}
