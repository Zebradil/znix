{ inputs, lib, ... }:
{
  flake-file.inputs.disko = {
    url = "github:nix-community/disko";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.modules.nixos.tuxedo = {
    imports =
      (with inputs.self.modules.nixos; [
        _1password
        audio
        boot
        determinate
        diff
        docker
        ephemeral-btrfs
        fido
        fonts
        gdm
        hardware-monitoring
        home-manager
        hyprland
        impermanence
        laptop
        locale
        nix-settings
        openssh
        sito
        sops
        tailscale
        tuxedo-disko
        tuxedo-hardware
        wireless
        zebradil
      ])
      ++ [ inputs.disko.nixosModules.disko ];

    networking.hostName = "tuxedo";
    networking.domain = "zebradil.dev";
    system.stateVersion = "25.11";

    determinate.enable = true;

    # sito fronts every cache from localhost (modules/shared/sito.nix), so the
    # shared static list would only double-query the remotes on a miss. The
    # force drops every other definition, hence hyprland's cachix is restated
    # here; trusted-public-keys is untouched, sito passes upstream signatures
    # through as-is.
    nix.settings.substituters = lib.mkForce [
      "http://127.0.0.1:5001"
      "https://hyprland.cachix.org"
    ];

    znix = {
      boot.enable = true;
      diff.enable = true;
      docker.enable = true;
      docker.binfmt.enable = true;
      hardware-monitoring.enable = true;
      ephemeral-btrfs.enable = true;
      impermanence.enable = true;
      wireless.enable = true;
      laptop.enable = true;
      fido.enable = true;
      tailscale.enable = true;
    };

    # Persistence configuration for various pluggable services lives here instead
    # of their corresponding modules because `environment.persistence` only exists
    # on impermanence hosts, evaluation on other hosts would fail otherwise.
    environment.persistence."/persist".directories = [
      "/var/lib/tailscale"
      # DynamicUser cache root, for sito's vmagent queue (modules/shared/sito.nix)
      # to survive a reboot while offline. Persisted whole because impermanence
      # would create it 0755 as a parent of a narrower entry, exposing the
      # dynamic-uid dirs systemd keeps behind it.
      {
        directory = "/var/cache/private";
        mode = "0700";
      }
    ];

    programs.zsh.enable = true;

    security.pam.loginLimits = [
      {
        domain = "@wheel";
        item = "nofile";
        type = "soft";
        value = "524288";
      }
      {
        domain = "@wheel";
        item = "nofile";
        type = "hard";
        value = "1048576";
      }
    ];
  };
}
