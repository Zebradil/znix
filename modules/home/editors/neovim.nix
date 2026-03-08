{ ... }:
{
  flake.modules.homeManager.neovim =
    { pkgs, ... }:
    {
      programs.neovim = {
        enable = true;
        extraPackages = with pkgs; [
          nodejs
          alejandra
          deadnix
          nixd
          nixfmt
          statix
        ];
      };
    };
}
