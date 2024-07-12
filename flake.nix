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
        ];

        # Auto upgrade nix package and the daemon service.
        services.nix-daemon.enable = true;
        nix.package = pkgs.nix;

        # Necessary for using flakes on this system.
        nix.settings.experimental-features = "nix-command flakes";

        # Create /etc/zshrc that loads the nix-darwin environment.
        programs.zsh.enable = true;

        # Set Git commit hash for darwin-version.
        system.configurationRevision = self.rev or self.dirtyRev or null;

        # Used for backwards compatibility, please read the changelog before changing.
        # $ darwin-rebuild changelog
        system.stateVersion = 4;

        # The platform the configuration will be used on.
        nixpkgs.hostPlatform = "aarch64-darwin";
        nixpkgs.config.allowUnfree = true;

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
              # _1password
              firefox-bin
              iterm2
              gh
              k9s
              keepassxc
              chezmoi
              neovim
              nixpkgs-fmt
              slack
              starship
              # syncthing
              # syncthingtray
              # tailscale
              # tailscale-systray
              zoom-us
              (vscode-with-extensions.override { vscodeExtensions = with vscode-extensions; [ jnoortheen.nix-ide asvetliakov.vscode-neovim ]; })
            ];

          services.syncthing.enable = true;

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
