{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  theme = builtins.fromJSON (builtins.readFile ./shell-theme.json);
in
lib.mkIf (config.znix.desktop.hyprland.shellPreset == "ashell") {
  programs.ashell = {
    enable = true;
    package = inputs.ashell.packages.${pkgs.stdenv.hostPlatform.system}.default;
    systemd.enable = true;
    settings = {
      appearance = {
        font_name = theme.font.name;
        scale_factor = theme.scaleFactor;
        style = "Solid";

        success_color = theme.colors.success;
        text_color = theme.colors.fg;
        workspace_colors = [
          theme.colors.accent
          "#b4befe"
          "#cba6f7"
        ];

        primary_color = {
          base = theme.colors.accent;
          text = theme.colors.bg;
        };

        danger_color = {
          base = theme.colors.danger;
          weak = theme.colors.warning;
        };

        background_color = {
          base = theme.colors.bg;
          weak = theme.colors.bgWeak;
          strong = theme.colors.bgStrong;
        };

        secondary_color = {
          base = theme.colors.secondary;
          strong = theme.colors.secondaryStrong;
        };
      };
      keyboard_layout.labels = {
        "English (US)" = "🇺🇸";
        "English (Dvorak)" = "◈";
        "Russian (phonetic, Dvorak)" = "🇷🇺";
      };
      modules = {
        center = [
          "WindowTitle"
        ];
        left = [
          "Workspaces"
        ];
        right = [
          "KeyboardLayout"
          "SystemInfo"
          [
            "Tempo"
            "Tray"
            "Privacy"
            "Settings"
          ]
        ];
      };
      workspaces = {
        visibility_mode = "MonitorSpecific";
      };
    };
  };
}
