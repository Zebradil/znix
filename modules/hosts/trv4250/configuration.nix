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
    imports = with inputs.self.modules.darwin; [
      diff
      nix-settings
      fonts
      defaults
      homebrew
      touch-id
      home-manager
      glashevich
    ];

    znix.diff.enable = true;

    environment.etc."nix/nix.custom.conf".text = ''
      trusted-users = root glashevich @admin
    '';

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
