_: {
  flake.modules.nixos.gdm = _: {
    services.displayManager = {
      enable = true;
      gdm.enable = true;
      # Pin the default session so GDM never depends on the mutable per-user
      # choice in /var/lib/AccountsService/users/<user>, which can get reset by
      # rebuilds and leave the session dropdown empty (login loop). Value is the
      # .desktop basename: "hyprland" = plain start-hyprland entry.
      defaultSession = "hyprland";
    };
  };
}
