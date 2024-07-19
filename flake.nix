{
  description = "Example Darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # nix-index-database.url = "github:mic92/nix-index-database";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mac-app-util.url = "github:hraban/mac-app-util";
  };

  outputs =
    { self
    , home-manager
    , mac-app-util
    , nix-darwin
    , nixpkgs
    }:
    let
      systemConfiguration = { pkgs, ... }: {

        # List packages installed in system profile. To search by name, run:
        # $ nix-env -qaP | grep wget
        environment.systemPackages = with pkgs; [
        ];

        fonts.packages = with pkgs; [
          iosevka-bin
          (nerdfonts.override { fonts = [ "IosevkaTerm" ]; })
        ];

        services = {
          nix-daemon.enable = true;
        };

        # Auto upgrade nix package
        nix.package = pkgs.nix;

        # Necessary for using flakes on this system.
        nix.settings.experimental-features = "nix-command flakes";

        # TODO: configure gpg integrations
        # programs.gnupg.agent.enable = true;

        # Set Git commit hash for darwin-version.
        system.configurationRevision = self.rev or self.dirtyRev or null;

        # Used for backwards compatibility, please read the changelog before changing.
        # $ darwin-rebuild changelog
        system.stateVersion = 4;

        nixpkgs = {
          hostPlatform = "aarch64-darwin";
          config.allowUnfree = true;
        };

        security.pam.enableSudoTouchIdAuth = true;

        system.defaults.dock.autohide = true;
        system.defaults.dock.mru-spaces = false;
        system.defaults.dock.show-recents = false;
        system.defaults.dock.static-only = true;
        system.defaults.dock.tilesize = 32;
        system.defaults.finder.AppleShowAllExtensions = true;
        system.defaults.finder.CreateDesktop = false;
        system.defaults.finder.FXDefaultSearchScope = "SCcf";
        system.defaults.finder.FXPreferredViewStyle = "Nlsv";
        system.defaults.finder.QuitMenuItem = true;
        system.defaults.finder.ShowPathbar = true;
        system.defaults.finder.ShowStatusBar = true;
        system.defaults.trackpad.Clicking = true;
        system.defaults.trackpad.Dragging = true;
        system.defaults.trackpad.TrackpadRightClick = true;
        system.defaults.trackpad.TrackpadThreeFingerDrag = true;
        system.defaults.universalaccess.closeViewScrollWheelToggle = true;
        system.defaults.universalaccess.closeViewZoomFollowsFocus = true;
        system.keyboard.enableKeyMapping = true;
      };

      userConfiguration = { ... }: {
        users.users.glashevich = {
          name = "glashevich";
          home = "/Users/glashevich";
        };
        home-manager.users.glashevich = { pkgs, ... }: {
          nixpkgs.config.allowUnfree = true;
          home.packages = with pkgs;
            [
              # Desktop apps
              alacritty
              iterm2
              keepassxc
              slack
              youtube-music
              zoom-us
              #_1password-gui # doesn't work when installed outside of /Applications
              #firefox-bin    # 1password extensions doesn't work if FF is installed outside of /Applications
              # (github:bandithedoge/nixpkgs-firefox-darwin)

              # Desktop-CLI integrations
              terminal-notifier

              # CLI apps
              bat
              btop
              delta
              k9s
              lazygit
              tmux
              translate-shell

              #CLI tools
              chezmoi
              curl
              direnv
              duf
              eza
              fd
              fzf
              gh
              go-task
              jq
              myks
              ripgrep
              rsync
              yq-go

              # shell
              starship
              zsh-completions

              # deprecated
              nixpkgs-fmt
            ];

          services.syncthing.enable = true;

          imports = [
            mac-app-util.homeManagerModules.default
          ];

          home.file = {
            ".local/bin" = {
              source = ./bin;
              recursive = true;
            };
            ".zsh/zshrc" = {
              source = ./zsh/zshrc;
              recursive = true;
            };
          };

          programs.neovim = {
            enable = true;
            extraPackages = with pkgs; [
              # common
              nodejs

              # astrocommunity.pack.nix deps
              alejandra
              deadnix
              nixd
              statix

            ];
          };

          programs.direnv = {
            enable = true;
            enableZshIntegration = true;
            nix-direnv.enable = true;
          };
          programs.zoxide = {
            enable = true;
            enableZshIntegration = true;
          };
          programs.zsh = {
            enable = true;
            dotDir = ".zsh";
            initExtra = builtins.readFile ./zsh/zshrc.zsh;
            sessionVariables = {
              _ZO_FZF_OPTS = ''+s --preview "exa -l --group-directories-first -T -L5 --color=always --color-scale {2..} | head -200"'';
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

          # The state version is required and should stay at the version you
          # originally installed.
          home.stateVersion = "24.05";
        };
      };
    in
    {
      # Build darwin flake using:
      # $ darwin-rebuild build --flake .#trv4250
      darwinConfigurations."trv4250" = nix-darwin.lib.darwinSystem {
        modules = [
          systemConfiguration
          home-manager.darwinModules.home-manager
          userConfiguration
        ];
      };

      # Expose the package set, including overlays, for convenience.
      darwinPackages = self.darwinConfigurations."trv4250".pkgs;
    };
}
