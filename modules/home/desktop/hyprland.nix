{ ... }:
{
  flake.modules.homeManager.hyprland =
    { pkgs, lib, ... }:
    lib.mkIf (pkgs.stdenv.isLinux) {
      wayland.windowManager.hyprland = {
        enable = true;
        settings = {
          "$mod" = "SUPER";
        };
      };
    };
}
