_: {
  flake.modules.homeManager.nushell =
    { lib, osConfig, ... }:
    let
      base = {
        programs.nushell = {
          enable = true;

          # Static env vars → rendered as $env.KEY = "value" in env.nu
          environmentVariables = {
            EDITOR = "nvim";
            NVIM_COMMAND = "nvim-profile";
            NVIM_PROFILE_NAME = "astro4";
            LANG = "en_US.UTF-8";
            LC_ALL = "en_US.UTF-8";
            LC_TIME = "en_DK.UTF-8";
            LESS = "--RAW-CONTROL-CHARS --mouse --wheel-lines=3 --quit-if-one-screen --ignore-case --tabs=4";
            MANPAGER = "nvim +Man!";
            DOCKER_BUILDKIT = "1";
            COMPOSE_DOCKER_CLI_BUILD = "1";
            USE_GKE_GCLOUD_AUTH_PLUGIN = "True";
          };

          # Dynamic env vars (nushell expressions) — appended to env.nu
          extraEnv = ''
            $env.WORKSPACE = $env.HOME
            $env.GPG_TTY = (^tty)
            $env.PATH = ($env.PATH | prepend ($env.HOME | path join ".local" "bin"))
          '';

          shellAliases = { };

          # config.nu
          extraConfig = ''
            $env.config = {
              show_banner: false
              edit_mode: vi
              history: {
                max_size: 100_000
                file_format: "sqlite"
                sync_on_enter: true
              }
              completions: {
                case_sensitive: false
                algorithm: "fuzzy"
              }
            }

            # Start polkit TTY agent for terminal-based U2F/password authentication.
            # Takes priority over the session-wide GUI agent (hyprpolkitagent) for
            # commands run in this terminal.
            if (which pkttyagent | is-not-empty) {
              pkttyagent --process $nu.pid &
            }
          '';
        };
      };

      # SQLite history db lives in ~/.config/nushell/history.sqlite3
      impermanence = lib.mkIf osConfig.znix.impermanence.enable {
        home.persistence."/persist".directories = [ ".config/nushell" ];
      };
    in
    lib.mkMerge [
      base
      impermanence
    ];
}
