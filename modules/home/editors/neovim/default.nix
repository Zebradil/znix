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
        xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.znix.repoDir}/modules/home/editors/neovim/nvim";
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
