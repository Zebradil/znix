{ ... }:
{
  flake.modules.homeManager.hyprland =
    { pkgs, ... }:
    {
      imports = [ ./_waybar.nix ];
      wayland.windowManager.hyprland = {
        enable = true;
        plugins = with pkgs; [
          # hyprlandPlugins.hyprbars
        ];
        settings = {
          "$mod" = "SUPER";
          bind = [
            "$mod, F, exec, firefox"
            "$mod, Q, exec, kitty"
            ", Print, exec, grimblast copy area"
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
    };
}
