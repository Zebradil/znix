{pkgs, ...}: {
  programs.neovim = {
    enable = true;
    extraPackages = with pkgs; [
      # common
      nodejs

      # astrocommunity.pack.nix deps
      alejandra
      deadnix
      nixd
      statix
    ];
  };
}
