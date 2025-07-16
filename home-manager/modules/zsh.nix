{ lib, ... }:
{
  programs.zsh = {
    enable = true;
    completionInit = "autoload -Uz compinit && compinit -C";
    dotDir = ".zsh";
    envExtra = ''
      export EDITOR=nv
      export LANG=en_US.UTF-8
      export LC_ALL=en_US.UTF-8
      export LC_TIME=en_DK.UTF-8
      export LESS='--mouse --wheel-lines=3 --quit-if-one-screen --ignore-case --tabs=4'
      export MANPAGER='nv +Man!'
      export NVIM_PROFILE_NAME=astro4
      export WORKSPACE=$HOME
      export ZVM_INIT_MODE=sourcing
      export STARSHIP_CONFIG=$XDG_CONFIG_HOME/starship.toml
    '';
    initContent = lib.mkMerge [
      (lib.mkOrder 550 ''
        zstyle ':completion:*' completer _complete _ignored _approximate
        zstyle ':completion:*' matcher-list "" 'm:{a-z}={A-Za-z}' 'l:|=* r:|=*' 'r:|[._-]=* r:|=*'
      '')
      (builtins.readFile ./zsh/zshrc.zsh)
    ];
    antidote = {
      enable = true;
      plugins = [
        "hcgraf/zsh-sudo"
        "jeffreytse/zsh-vi-mode"
        # "marzocchi/zsh-notify"
        "MichaelAquilina/zsh-auto-notify"
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
    # zprof.enable = true;

    shellAliases = {
      ndr = "nix-direnv-reload";
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
