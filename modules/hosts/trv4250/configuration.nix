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
      trv4250-shell
      sito
    ];

    znix.diff.enable = true;
    znix.hosts.trv4250.enable = true;

    determinateNix = {
      enable = true;
      customSettings = (inputs.self.lib.nixSettings or { }) // {
        # sito fronts every cache from localhost (modules/shared/sito.nix), so
        # the shared static list would only double-query the remotes on a miss.
        # No explicit fallback: Determinate's own customSettings definition
        # already appends cache.nixos.org after this entry.
        substituters = [ "http://127.0.0.1:5001" ];
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
      nixosVmBasedLinuxBuilder = {
        enable = true;
        # nixpkgs' `nixos/lib/qemu-common.nix` pins `gic-version=2` for
        # aarch64-linux guests on darwin hosts, but HVF only emulates GICv3, so
        # qemu aborts with "HVF does not support GICv2 emulation" and launchd's
        # KeepAlive respawns it in a loop (each respawn re-tars the whole store
        # into an erofs image, burning a core). Repeating `-machine` merges into
        # the earlier one, so this overrides only the GIC version and keeps HVF.
        config.virtualisation.qemu.options = [ "-machine gic-version=3" ];
      };
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
