_: {
  flake.modules.homeManager.dotfiles =
    { config, ... }:
    {
      home.file = {
        ".editorconfig".source = config.znix.mkRepoLink "modules/home/dotfiles/editorconfig";
        ".oxfmtrc.jsonc".source = config.znix.mkRepoLink "modules/home/dotfiles/oxfmtrc.jsonc";
        ".prettierrc.yaml".source = config.znix.mkRepoLink "modules/home/dotfiles/prettierrc.yaml";
        ".cargo/binstall.toml".source = config.znix.mkRepoLink "modules/home/dotfiles/cargo/binstall.toml";
        ".config/fd/ignore".source = config.znix.mkRepoLink "modules/home/dotfiles/fd/ignore";
        ".config/ghostty/config".source = config.znix.mkRepoLink "modules/home/dotfiles/ghostty/config";
        ".config/htop/htoprc".source = config.znix.mkRepoLink "modules/home/dotfiles/htop/htoprc";
        ".config/k9s/aliases.yaml".source = config.znix.mkRepoLink "modules/home/dotfiles/k9s/aliases.yaml";
        ".config/k9s/config.yaml".source = config.znix.mkRepoLink "modules/home/dotfiles/k9s/config.yaml";
        ".config/k9s/skins/transparent.yaml".source =
          config.znix.mkRepoLink "modules/home/dotfiles/k9s/skins/transparent.yaml";
        ".config/nvim/spell/en.utf-8.add".source =
          config.znix.mkRepoLink "modules/home/dotfiles/nvim/spell/en.utf-8.add";
        ".config/tridactyl/tridactylrc".source =
          config.znix.mkRepoLink "modules/home/dotfiles/tridactyl/tridactylrc";
        ".config/wezterm/wezterm.lua".source =
          config.znix.mkRepoLink "modules/home/dotfiles/wezterm/wezterm.lua";
      };
    };
}
