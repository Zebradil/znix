{
  config,
  inputs,
  pkgs,
  ...
}:
{
  programs.ashell = {
    enable = true;
    package = inputs.ashell.packages.${pkgs.stdenv.hostPlatform.system}.default;
    systemd.enable = true;
    settings = {
      appearance = {
        font_name = "IosevkaTerm Nerd Font";
        scale_factor = 1.3;
        bar = {
          surface = "solid";
          padding = [
            "none"
            "xxs"
          ];
        };

        success_color = "#a6e3a1";
        text_color = "#cdd6f4";
        workspace_colors = [
          "#fab387"
          "#b4befe"
          "#cba6f7"
        ];

        primary_color = {
          base = "#fab387";
          text = "#1e1e2e";
        };

        danger_color = {
          base = "#f38ba8";
          weak = "#f9e2af";
        };

        background_color = {
          base = "#1e1e2e";
          weak = "#313244";
          strong = "#45475a";
        };
      };
      keyboard_layout.labels = {
        "English (US)" = "US";
        "English (Dvorak)" = "Dv";
        "Russian (phonetic, Dvorak)" = "Ё";
        "Russian (phonetic)" = "Я";
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

  # Hot-reload does not apply bar surface/layout changes; restart on any config change.
  systemd.user.services.ashell.Unit.X-Restart-Triggers = [
    config.xdg.configFile."ashell/config.toml".source
  ];
}
