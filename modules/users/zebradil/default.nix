{ self, ... }:
{
  flake.modules.nixos.zebradil =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
    in
    {
      users.mutableUsers = false;
      users.users.zebradil = {
        isNormalUser = true;
        shell = pkgs.zsh;
        extraGroups = ifTheyExist [
          "audio"
          "docker"
          "git"
          "i2c"
          "libvirtd"
          "network"
          "plugdev"
          "podman"
          "tss"
          "video"
          "wheel"
          "wireshark"
        ];

        openssh.authorizedKeys.keys = lib.splitString "\n" (builtins.readFile ./ssh.pub);
        hashedPasswordFile = config.sops.secrets.password.path;
        packages = [ pkgs.home-manager ];
      };

      sops.defaultSopsFile = ../../../secrets/users/zebradil.yaml;
      sops.secrets.password.neededForUsers = true;

      # Home persistence is system-owned. Current impermanence does ALL home
      # bind-mounting in its NixOS module (its home-manager.nix is validation-only);
      # so the mounts must be declared system-side. Rather than hand-copy the dir
      # list (partly COMPUTED — claude persists each profile's configDir, opencode
      # several dirs — so a hand list silently drifts), source it from the single
      # source of truth: the standalone home config's aggregated home.persistence.
      # Reading a string list forces home OPTION eval only, never a home build, so
      # the fast home-switch loop is unaffected; nixos-rebuild is needed only when
      # the persisted-dir SET changes (rare).
      environment.persistence."/persist".users.zebradil = lib.mkIf config.znix.impermanence.enable {
        directories =
          self.homeConfigurations."zebradil@tuxedo".config.home.persistence."/persist".directories;
      };

      sops.secrets."u2f_keys/${config.networking.hostName}" = lib.mkIf config.znix.fido.enable {
        path = "/home/zebradil/.config/Yubico/u2f_keys";
        owner = "zebradil";
        mode = "0400";
      };
    };
}
