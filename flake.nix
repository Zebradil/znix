{
  description = "My Darwin system + Home Manager flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/8809585e6937d0b07fc066792c8c9abf9c3fe5c4";

    flake-utils.url = "github:numtide/flake-utils";

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

  outputs = inputs @ {
    determinate,
    flake-utils,
    gke-kubeconfiger,
    home-manager,
    homebrew-bundle,
    homebrew-cask,
    homebrew-core,
    mac-app-util,
    nix-darwin,
    nix-homebrew,
    nix-index-database,
    nixpkgs,
    self,
  }: let
    user = "glashevich";
    system = "aarch64-darwin";
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };

    darwinConfiguration = {...}: {
      nixpkgs = {
        hostPlatform = "aarch64-darwin";
        config.allowUnfree = true;
      };

      # To inititalize shell with nix-darwin environment,
      # enable zsh in addition to Home Manager's zsh.
      # See https://github.com/LnL7/nix-darwin/issues/922
      programs.zsh.enable = true;

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
          replacement = "/Users/${user}/Applications/Home Manager Trampolines/YouTube Music.app";
        };
      };

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 4;
    };

    userConfiguration = {...}: {
      users.users.${user} = {
        name = user;
        home = "/Users/${user}";
      };
      home-manager.users.${user} = (
        import ./home-manager {
          inherit
            gke-kubeconfiger
            mac-app-util
            nix-index-database
            nixpkgs
            system
            user
            ;
        }
      );
    };
  in {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#trv4250
    darwinConfigurations."trv4250" = nix-darwin.lib.darwinSystem {
      modules = [
        determinate.darwinModules.default
        (import ./hosts/shared.nix {
          inherit pkgs user;
        })
        darwinConfiguration
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
  };
}
