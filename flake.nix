{
  description = "Example Darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-firefox-darwin.url = "github:bandithedoge/nixpkgs-firefox-darwin";
    # nix-index-database.url = "github:mic92/nix-index-database";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self
    , home-manager
    , nix-darwin
    , nixpkgs-firefox-darwin
    , nixpkgs
    }:
    let
      systemConfiguration = { pkgs, ... }: {

        # List packages installed in system profile. To search by name, run:
        # $ nix-env -qaP | grep wget
        environment.systemPackages = with pkgs; [
          _1password-gui
          tailscale
        ];

        fonts.packages = with pkgs; [
          iosevka-bin
          (nerdfonts.override { fonts = [ "IosevkaTerm" ]; })
        ];

        services = {
          nix-daemon.enable = true;
          tailscale.enable = true;
        };

        # Auto upgrade nix package
        nix.package = pkgs.nix;

        # Necessary for using flakes on this system.
        nix.settings.experimental-features = "nix-command flakes";

        # Create /etc/zshrc that loads the nix-darwin environment.
        programs.zsh.enable = true;

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
      };
      userConfiguration = { pkgs, ... }: {
        users.users.glashevich = {
          name = "glashevich";
          home = "/Users/glashevich";
        };
        home-manager.users.glashevich = { pkgs, ... }: {
          nixpkgs.overlays = [ nixpkgs-firefox-darwin.overlay ];
          nixpkgs.config.allowUnfree = true;
          home.packages = with pkgs;
            [
              # Desktop apps
              alacritty
              firefox-bin
              iterm2
              keepassxc
              slack
              zoom-us
              # _1password
              # tailscale-systray

              # CLI apps
              bat
              btop
              delta
              k9s
              neovim
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
              ripgrep
              rsync
              yq-go

              # astrocommunity.pack.nix deps
              alejandra
              deadnix
              nixd
              statix

              # neovim plugin deps
              go
              nodejs_22

              # shell
              antidote
              bash
              starship
              zoxide
              zsh-completions

              # deprecated
              nixpkgs-fmt
            ];

          services.syncthing.enable = true;

          home.file = {
            ".local/bin" = {
              source = ./bin;
              recursive = true;
            };
            ".zsh" = {
              source = ./zsh;
              recursive = true;
            };
          };

          programs.zsh = {
            enable = true;
            dotDir = ".zsh";
            antidote = {
              enable = true;
              plugins = [
                "hcgraf/zsh-sudo"
                "jeffreytse/zsh-vi-mode"
                "marzocchi/zsh-notify"
                "robbyrussell/oh-my-zsh path:lib/git.zsh"
                "robbyrussell/oh-my-zsh path:plugins/docker-machine"
                "robbyrussell/oh-my-zsh path:plugins/git"
                "unixorn/git-extra-commands"
                "zchee/zsh-completions"
                "zdharma-continuum/history-search-multi-word"
                "zsh-users/zsh-autosuggestions"
                "zsh-users/zsh-history-substring-search"
                "zsh-users/zsh-syntax-highlighting"
                "djui/alias-tips"
              ];
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
