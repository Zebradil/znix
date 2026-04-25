{ inputs, ... }:
{
  flake-file.inputs.disko = {
    url = "github:nix-community/disko";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.modules.nixos.tuxedo = {
    imports =
      (with inputs.self.modules.nixos; [
        _1password
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
        nix-settings
        openssh
        sops
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

    znix = {
      boot.enable = true;
      diff.enable = true;
      docker.enable = true;
      hardware-monitoring.enable = true;
      ephemeral-btrfs.enable = true;
      impermanence.enable = true;
      wireless.enable = true;
      laptop.enable = true;
      fido.enable = true;
    };

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
