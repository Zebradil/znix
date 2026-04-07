_: {
  flake.modules.homeManager.alacritty = {
    programs.alacritty = {
      enable = true;
      theme = "ayu_dark";
      settings = {
        font = {
          size = 12;
          normal = {
            family = "IosevkaTerm Nerd Font";
            style = "Regular";
          };
        };
      };
    };
  };
}
