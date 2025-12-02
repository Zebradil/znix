{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    bottom
    fd
    gcc
    gdu
    git
    gnumake
    lazygit
    luarocks
    nodejs
    ripgrep
    tree-sitter
    unzip

    # astrocommunity.pack.nix deps
    deadnix
    nixd
    nixfmt
    statix
  ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
  };

  home.file = {
    ".config/nvim".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/code/github.com/zebradil/znix/home-manager/modules/neovim/nvim";
  };
}
