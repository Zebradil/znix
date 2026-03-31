{ inputs, self, ... }:
{
  flake-file.inputs = {
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
  };

  flake.modules.darwin.trv4250 = {
    imports = [
      inputs.determinate.darwinModules.default
    ] ++ (with inputs.self.modules.darwin; [
      diff
      nix-settings
      fonts
      defaults
      homebrew
      touch-id
      home-manager
      glashevich
    ]);

    znix.diff.enable = true;

    determinateNix = {
      enable = true;
      customSettings = (inputs.self.lib.nixSettings or { }) // {
        trusted-users = [
          "root"
          "glashevich"
          "@admin"
        ];
      };
      determinateNixd.garbageCollector.strategy = "automatic";
    };

    programs.zsh.enable = true;

    system = {
      primaryUser = "glashevich";
      defaults.CustomUserPreferences."digital.twisted.noTunes" = {
        replacement = "/Users/glashevich/Applications/Edge Apps.localized/YouTube Music.app";
      };

      configurationRevision = self.rev or self.dirtyRev or null;
      stateVersion = 4;
    };
  };
}
