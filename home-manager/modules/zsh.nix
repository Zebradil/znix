{...}: {
  programs.zsh = {
    enable = true;
    completionInit = "autoload -Uz compinit && compinit -C";
    dotDir = ".zsh";
    envExtra = ''
      export BAT_THEME=OneHalfDark
      export EDITOR=nv
      export LANG=en_US.UTF-8
      export LC_ALL=en_US.UTF-8
      export LC_TIME=en_DK.UTF-8
      export LESS='--mouse --wheel-lines=3 --quit-if-one-screen --ignore-case --tabs=4'
      export MANPAGER='nv +Man!'
      export NVIM_PROFILE_NAME=astro4
      export ZVM_INIT_MODE=sourcing
    '';
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
      extended = true;
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
