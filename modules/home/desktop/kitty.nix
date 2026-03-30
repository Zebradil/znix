_: {
  flake.modules.homeManager.kitty = {
    programs.kitty = {
      enable = true;
      font = {
        name = "IosevkaTerm NFM";
        size = 13;
      };
    };
  };
}
