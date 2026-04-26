{ pkgs, ... }:
{
  home.packages = with pkgs; [
    grimblast
    wl-clipboard
    libnotify
  ];
  wayland.windowManager.hyprland.settings.bind = [
    ", Print, exec, hypr-exec grimblast --notify copysave area"
    "$mod, Print, exec, hypr-exec grimblast --notify copysave output"
    "$mod SHIFT, Print, exec, hypr-exec grimblast --notify copysave active"
  ];
}
