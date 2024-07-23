{...}: {
  programs.zsh = {
    enable = true;
    dotDir = ".zsh";
    envExtra = "export ZVM_INIT_MODE=sourcing";
    initExtra = builtins.readFile ./zsh/zshrc.zsh;
    sessionVariables = {
      _ZO_FZF_OPTS = "+s --preview 'exa -l --group-directories-first -T -L5 --color=always --color-scale {2..} | head -200'";
    };
    antidote = {
      enable = true;
      plugins = [
        "hcgraf/zsh-sudo"
        "jeffreytse/zsh-vi-mode"
        "marzocchi/zsh-notify"
        "robbyrussell/oh-my-zsh path:lib/git.zsh"
        # "robbyrussell/oh-my-zsh path:plugins/git"
        "unixorn/git-extra-commands"
        "zchee/zsh-completions"
        "zdharma-continuum/history-search-multi-word"
      ];
    };
    autosuggestion.enable = true;
    history = {
      ignoreAllDups = true;
      ignoreSpace = true;
      share = true;
    };
    historySubstringSearch.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      tf = "terraform";
    };
  };

  home.file = {
    ".zsh/zshrc" = {
      source = ./zsh/zshrc;
      recursive = true;
    };
  };
}
