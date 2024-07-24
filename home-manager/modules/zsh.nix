{...}: {
  programs.zsh = {
    enable = true;
    dotDir = ".zsh";
    envExtra = "export ZVM_INIT_MODE=sourcing";
    initExtra = builtins.readFile ./zsh/zshrc.zsh;
    initExtraBeforeCompInit = ''
      zstyle ':completion:*' completer _complete _ignored _approximate
      zstyle ':completion:*' matcher-list "" 'm:{a-z}={A-Za-z}' 'l:|=* r:|=*' 'r:|[._-]=* r:|=*'
    '';
    antidote = {
      enable = true;
      plugins = [
        "hcgraf/zsh-sudo"
        "jeffreytse/zsh-vi-mode"
        "marzocchi/zsh-notify"
        "zchee/zsh-completions"
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
