{ ... }:
{
  flake.modules.homeManager.zsh =
    {
      lib,
      config,
      osConfig,
      ...
    }:
    let
      base = {
        programs.zsh = {
          enable = true;
          completionInit = "autoload -Uz compinit && compinit -C";
          dotDir = "${config.home.homeDirectory}/.zsh";
          envExtra = ''
            export EDITOR=nvim
            export NVIM_COMMAND=nvim-profile
            export NVIM_PROFILE_NAME=astro4
            export LANG=en_US.UTF-8
            export LC_ALL=en_US.UTF-8
            export LC_TIME=en_DK.UTF-8
            export LESS='--mouse --wheel-lines=3 --quit-if-one-screen --ignore-case --tabs=4'
            export MANPAGER='nvim +Man!'
            export WORKSPACE=$HOME
            export ZVM_INIT_MODE=sourcing
            export STARSHIP_CONFIG=$XDG_CONFIG_HOME/starship.toml
          '';
          sessionVariables.USE_GKE_GCLOUD_AUTH_PLUGIN = "True";
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
              "MichaelAquilina/zsh-auto-notify"
              "zchee/zsh-completions"
            ];
          };
          autosuggestion.enable = true;
          history = {
            extended = true;
            ignoreAllDups = true;
            ignoreSpace = true;
            save = 100000;
            share = true;
            size = 100000;
          };
          historySubstringSearch.enable = true;
          syntaxHighlighting.enable = true;

          shellAliases = {
            ndr = "nix-direnv-reload";
            tf = "terraform";
          };
        };

        home.file.".zsh/zshrc".source = config.znix.mkRepoLink "modules/home/shell/zsh/zshrc";
      };

      impermanence = lib.mkIf osConfig.znix.impermanence.enable {
        home.persistence."/persist".files = [ ".zsh/.zsh_history" ];
      };

    in
    lib.mkMerge [
      base
      impermanence
    ];
}
