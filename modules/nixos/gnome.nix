_: {
  flake.modules.nixos.gnome = _: {
    services = {
      displayManager.gdm.enable = true;
      desktopManager.gnome.enable = true;
    };

    # A rebuild that restarts the display manager kills the running session.
    # DM changes apply on next reboot instead.
    systemd.services.display-manager.restartIfChanged = false;
  };
}
