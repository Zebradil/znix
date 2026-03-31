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
          bind = [
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
