_: {
  flake.modules.nixos.gdm = _: {
    services.displayManager = {
      enable = true;
      gdm.enable = true;
    };
  };
}
