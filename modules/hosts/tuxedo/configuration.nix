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
        diff
        ephemeral-btrfs
        fido
        fonts
        gdm
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
    system.stateVersion = "22.05";

    znix = {
      boot.enable = true;
      diff.enable = true;
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
