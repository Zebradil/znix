_: {
  flake.modules.homeManager.syncthing = _: {
    services.syncthing.enable = true;
  };
}
