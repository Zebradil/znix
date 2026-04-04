{ pkgs, ... }:
{
  home.packages = with pkgs; [
    grimblast
    wl-clipboard
    libnotify
  ];
  wayland.windowManager.hyprland.settings.bind = [
    ", Print, exec, grimblast --notify copysave area"
    "$mod, Print, exec, grimblast --notify copysave output"
    "$mod SHIFT, Print, exec, grimblast --notify copysave active"
  ];
}
