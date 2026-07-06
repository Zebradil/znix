{ inputs, ... }:
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
      determinate
      diff
      nix-settings
      fonts
      defaults
      homebrew
      touch-id
      home-manager
      glashevich
      trv4250-claude
      trv4250-shell
    ];

    znix.diff.enable = true;
    znix.hosts.trv4250.enable = true;

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
      # Linux builder so this aarch64-darwin host can *build* aarch64-linux
      # (not just substitute) — e.g.
      # `nix build .#nixosConfigurations.toddler...sdImage`.
      #
      # We use Determinate's NixOS-VM-based builder rather than its native
      # (Virtualization.framework) builder: the native one is entitlement-gated
      # per FlakeHub account and ours isn't granted, so it leaves
      # `external-builders = []` at runtime. The VM builder needs no entitlement
      # and on Apple Silicon runs aarch64-linux at native speed via apple-virt.
      # (Also distinct from vanilla nix-darwin `nix.linux-builder`, which fights
      # Determinate — this is Determinate's own integrated option.)
      nixosVmBasedLinuxBuilder.enable = true;
    };

    programs.zsh.enable = true;

    system = {
      primaryUser = "glashevich";
      defaults.CustomUserPreferences."digital.twisted.noTunes" = {
        replacement = "/Users/glashevich/Applications/Home Manager Apps/YouTube Music Desktop App.app";
      };

      stateVersion = 4;
    };
  };
}
