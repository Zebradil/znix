{ lib, pkgs, ... }:
let
  hl = import ./_lua.nix { inherit lib; };
in
{
  home.packages = with pkgs; [
    grimblast
    wl-clipboard
    libnotify
  ];
  wayland.windowManager.hyprland.settings.bind = [
    (hl.bindExec "Print" "hypr-exec grimblast --notify copysave area")
    (hl.bindExec "SUPER + Print" "hypr-exec grimblast --notify copysave output")
    (hl.bindExec "SUPER + SHIFT + Print" "hypr-exec grimblast --notify copysave active")
  ];
}
