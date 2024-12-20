{
  description = "Example Darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/8809585e6937d0b07fc066792c8c9abf9c3fe5c4";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0.1";

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    gke-kubeconfiger = {
      url = "github:Zebradil/gke-kubeconfiger";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };

    mac-app-util.url = "github:hraban/mac-app-util";
  };

  outputs = {
    self,
    determinate,
    home-manager,
    mac-app-util,
    nix-darwin,
    nix-homebrew,
    nix-index-database,
    nixpkgs,
    ...
  } @ inputs: let
    user = "glashevich";
    systemConfiguration = {pkgs, ...}: {
      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages = [];

      # To inititalize shell with nix-darwin environment,
      # enable zsh in addition to Home Manager's zsh.
      # See https://github.com/LnL7/nix-darwin/issues/922
      programs.zsh.enable = true;

      fonts.packages = with pkgs; [
        iosevka-bin
        (nerdfonts.override {fonts = ["IosevkaTerm"];})
      ];

      homebrew = {
        enable = true;

        onActivation = {
          autoUpdate = true;
        };
        brews = ["displayplacer"];
        casks = [
          # "firefox"
          # "1password"
          "flameshot"
          "notunes"
          "orbstack"
        ];
      };

      services.nix-daemon.enable = true;

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      # Allow myself to use substitutes
      nix.settings.trusted-users = [user];

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
      system.defaults.dock.orientation = "right";
      system.defaults.dock.show-recents = false;
      system.defaults.dock.static-only = true;
      system.defaults.dock.tilesize = 32;
      system.defaults.finder.AppleShowAllExtensions = true;
      # yabai needs CreateDesktop to be enabled
      # system.defaults.finder.CreateDesktop = false;
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
          "com.apple.scrollwheel.scaling" = -1;
        };
        "digital.twisted.noTunes" = {
          replacement = "/Users/glashevich/Applications/Home Manager Trampolines/YouTube Music.app";
        };
      };
    };

    userConfiguration = {...}: {
      users.users.${user} = {
        name = user;
        home = "/Users/${user}";
      };
      home-manager.users.${user} = {pkgs, ...}: let
        xdgHome = "/Users/${user}/Workspace";
        xdg = {
          enable = true;
          cacheHome = "${xdgHome}/.cache";
          configHome = "${xdgHome}/.config";
          dataHome = "${xdgHome}/.local/share";
          stateHome = "${xdgHome}/.local/state";
        };
      in {
        imports = [
          mac-app-util.homeManagerModules.default
          nix-index-database.hmModules.nix-index
          ./home-manager/modules/google-cloud-sdk.nix
          ./home-manager/modules/neovim.nix
          ./home-manager/modules/starship.nix
          ./home-manager/modules/zoxide.nix
          ./home-manager/modules/zsh.nix
        ];

        xdg = xdg;

        nixpkgs = {
          config.allowUnfree = true;
          overlays = [
            (final: _prev: {
              gke-kubeconfiger = inputs.gke-kubeconfiger.defaultPackage.${final.system};
            })
          ];
        };

        home.packages = with pkgs; [
          # Desktop apps
          alacritty
          iterm2
          keepassxc
          skhd
          slack
          yabai
          youtube-music
          zoom-us
          #_1password-gui # doesn't work when installed outside of /Applications
          #firefox-bin    # 1password extensions doesn't work if FF is installed outside of /Applications
          # (github:bandithedoge/nixpkgs-firefox-darwin)

          # Desktop-CLI integrations
          tridactyl-native
          terminal-notifier

          # CLI apps
          bat
          btop
          delta
          k9s
          lazygit
          tailscale
          tmux
          translate-shell

          #CLI tools
          bashInteractive
          chezmoi
          coreutils
          curl
          direnv
          duf
          eza
          fd
          fzf
          gh
          ghorg
          git
          gke-kubeconfiger
          gnused
          go-task
          goreleaser
          inetutils
          jq
          just
          kubectl
          kubernetes-helm
          moreutils
          myks
          ncdu
          rage
          rancher
          ripgrep
          rsync
          skopeo
          terraform
          velero
          vendir
          watchexec
          wget
          yq-go
          ytt

          # languages
          go
          gofumpt

          cargo
          clippy
          rust-analyzer
          rustfmt

          # shell
          zsh-completions
        ];

        services.syncthing.enable = true;

        home.file = {
          "${xdgHome}/.local/bin" = {
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
        determinate.darwinModules.default
        systemConfiguration
        home-manager.darwinModules.home-manager
        userConfiguration
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            inherit user;
            enable = true;
            taps = {
              "homebrew/homebrew-core" = inputs.homebrew-core;
              "homebrew/homebrew-cask" = inputs.homebrew-cask;
              "homebrew/homebrew-bundle" = inputs.homebrew-bundle;
            };
            mutableTaps = false;
            enableRosetta = true;
            autoMigrate = true;
          };
        }
      ];
    };

    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations."trv4250".pkgs;
  };
}
