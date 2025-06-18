{
  home-manager,
  home-manager-user-configuration,
  homebrew-bundle,
  homebrew-cask,
  homebrew-core,
  nix-darwin,
  nix-homebrew,
  nixpkgs,
  self,
}:
let
  user = "glashevich";
  host = "trv4250";
  system = "aarch64-darwin";

  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };

  userConfiguration =
    { ... }:
    {
      users.users.${user} = {
        name = user;
        home = "/Users/${user}";
      };
      home-manager.users.${user} = nixpkgs.lib.mkMerge [
        (home-manager-user-configuration { inherit pkgs user; })
        {
          home.packages = with pkgs; [
            iterm2
            terminal-notifier
            skhd
          ];
        }
      ];
    };

  darwinConfiguration =
    { ... }:
    {
      imports = [ ./yabai.nix ];

      programs.zsh.enable = true;

      nix.enable = false;
      nixpkgs.hostPlatform = system;

      environment.etc."nix/nix.custom.conf".text = ''
        trusted-users = ${user}
        lazy-trees = true
      '';

      homebrew = {
        enable = true;

        onActivation.autoUpdate = true;
        brews = [ "displayplacer" ];
        casks = [
          # "firefox"
          # "1password"
          "flameshot"
          "notunes"
          "orbstack"
          "orcaslicer"
        ];
      };

      security.pam.services.sudo_local.touchIdAuth = true;

      system.primaryUser = user;
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
in
{
  ${host} = nix-darwin.lib.darwinSystem {
    modules = [
      (import ../shared.nix { inherit pkgs user; })
      darwinConfiguration
      home-manager.darwinModules.home-manager
      userConfiguration
      nix-homebrew.darwinModules.nix-homebrew
      {
        nix-homebrew = {
          inherit user;
          enable = true;
          taps = {
            "homebrew/homebrew-core" = homebrew-core;
            "homebrew/homebrew-cask" = homebrew-cask;
            "homebrew/homebrew-bundle" = homebrew-bundle;
          };
          mutableTaps = false;
          enableRosetta = true;
          autoMigrate = true;
        };
      }
    ];
  };
}
