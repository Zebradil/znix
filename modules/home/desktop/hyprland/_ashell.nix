{ inputs, pkgs, ... }:
{
  programs.ashell = {
    enable = true;
    package = inputs.ashell.packages.${pkgs.stdenv.hostPlatform.system}.default;
    systemd.enable = true;
    settings = {
      appearance = {
        scale_factor = 1.25;
        style = "Solid";

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

        secondary_color = {
          base = "#11111b";
          strong = "#1b1b25";
        };
      };
      modules = {
        center = [
          "WindowTitle"
        ];
        left = [
          "Workspaces"
        ];
        right = [
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
