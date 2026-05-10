_: {
  flake.modules.homeManager.btop = _: {
    programs.btop = {
      enable = true;
      settings = {
        color_theme = "Default";
        proc_per_core = true;
        vim_keys = true;
      };
    };
  };
}
