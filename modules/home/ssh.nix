_: {
  flake.modules.homeManager.ssh = _: {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      includes = [
        "~/.orbstack/ssh/config"
        "conf.d/*"
      ];
    };
  };
}
