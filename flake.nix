{
  description = "Example Darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mac-app-util.url = "github:hraban/mac-app-util";
  };

  outputs = {
    self,
    home-manager,
    mac-app-util,
    nix-darwin,
    nix-index-database,
    nixpkgs,
  }: let
    systemConfiguration = {pkgs, ...}: {
      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages = with pkgs; [
      ];

      fonts.packages = with pkgs; [
        iosevka-bin
        (nerdfonts.override {fonts = ["IosevkaTerm"];})
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

      system.defaults.CustomUserPreferences = {
        NSGlobalDomain = {
          AppleSpacesSwitchOnActivate = true;
          AppleInterfaceStyle = "Dark";
          InitialKeyRepeat = 15; # slider values: 120, 94, 68, 35, 25, 15
          KeyRepeat = 2; # slider values: 120, 90, 60, 30, 12, 6, 2
        };
      };
    };

    userConfiguration = {...}: {
      users.users.glashevich = {
        name = "glashevich";
        home = "/Users/glashevich";
      };
      home-manager.users.glashevich = {pkgs, ...}: {
        imports = [
          mac-app-util.homeManagerModules.default
          nix-index-database.hmModules.nix-index
          ./home-manager/modules/google-cloud-sdk.nix
          ./home-manager/modules/neovim.nix
          ./home-manager/modules/zoxide.nix
          ./home-manager/modules/zsh.nix
        ];

        nixpkgs.config.allowUnfree = true;
        home.packages = with pkgs; [
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
          goreleaser
          jq
          just
          kubectl
          kubeswitch
          moreutils
          myks
          ripgrep
          rsync
          velero
          vendir
          yq-go

          # languages
          go

          # services
          podman

          # shell
          starship
          zsh-completions
        ];

        services.syncthing.enable = true;

        home.file = {
          ".local/bin" = {
            source = ./bin;
            recursive = true;
          };
        };

        programs.direnv = {
          enable = true;
          nix-direnv.enable = true;
        };
        programs.fzf.enable = true;
        programs.nix-index.enable = true;

        # The state version is required and should stay at the version you
        # originally installed.
        home.stateVersion = "24.05";
      };
    };
  in {
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
