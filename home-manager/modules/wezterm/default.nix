{ config, ... }:
{
  programs.wezterm = {
    enable = true;
    enableZshIntegration = true;
  };

  home.file = {
    ".config/wezterm/wezterm.lua".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/code/github.com/zebradil/znix/home-manager/modules/wezterm/wezterm.lua";
  };
}
