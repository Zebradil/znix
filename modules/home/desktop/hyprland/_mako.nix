{ config, lib, ... }:
let
  theme = builtins.fromJSON (builtins.readFile ./shell-theme.json);
in
lib.mkIf (config.znix.desktop.hyprland.shellPreset == "ashell") {
  services.mako = {
    enable = true;
    settings = {
      default-timeout = 5000;
      border-radius = theme.radius;
      background-color = "${theme.colors.bg}ee";
      text-color = theme.colors.fg;
      border-color = theme.colors.accent;
      border-size = 2;
    };
  };
}
