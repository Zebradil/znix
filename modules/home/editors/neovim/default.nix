{ ... }:
{
  flake.modules.homeManager.neovim =
    {
      pkgs,
      lib,
      config,
      osConfig,
      ...
    }:
    let
      # TODO: consider a global znix.repoDir option so other modules can also use out-of-store symlinks
      znixDir = "${config.home.homeDirectory}/code/github.com/zebradil/znix";
      base = {
        programs.neovim = {
          enable = true;
          extraPackages = with pkgs; [
            nodejs
            deadnix
            nixd
            nixfmt
            statix
          ];
        };
        # Symlink the entire nvim dir so all configs remain writable (edit without rebuilding)
        xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink "${znixDir}/modules/home/editors/neovim/nvim";
      };
      impermanence = lib.mkIf osConfig.znix.impermanence.enable {
        home.persistence."/persist".directories = [
          ".config/github-copilot"
        ];
      };
    in
    lib.mkMerge [
      base
      impermanence
    ];
}
