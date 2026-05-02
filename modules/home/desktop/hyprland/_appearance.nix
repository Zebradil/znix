{ pkgs, ... }:
{
  home.pointerCursor = {
    name = "catppuccin-mocha-dark-cursors";
    package = pkgs.catppuccin-cursors.mochaDark;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  gtk = {
    enable = true;
    theme = {
      name = "catppuccin-mocha-mauve-standard";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "mauve" ];
        variant = "mocha";
      };
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.catppuccin-papirus-folders.override {
        accent = "mauve";
        flavor = "mocha";
      };
    };
    font = {
      name = "IosevkaTerm Nerd Font";
      size = 11;
    };
  };

  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    Unit = {
      Description = "PolicyKit Authentication Agent (GNOME)";
      After = [ "hyprland-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "hyprland-session.target" ];
  };

  wayland.windowManager.hyprland.settings = {
    general = {
      gaps_in = 0;
      gaps_out = 0;
      border_size = 2;
    };
    env = [
      "XCURSOR_SIZE,24"
      "HYPRCURSOR_SIZE,24"
      "HYPRCURSOR_THEME,catppuccin-mocha-dark-cursors"
      "GTK_THEME,catppuccin-mocha-mauve-standard"
    ];
    workspace = [
      "w[tv1], border:false"
    ];
  };
}
