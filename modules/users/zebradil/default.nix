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

      # Integrated home: sweep every home module plus this user's standalone
      # profile (identity, persistence, claude/impermanence values). The same
      # profile backs the standalone homeConfigurations."zebradil@tuxedo".
      home-manager.useGlobalPkgs = true;
      home-manager.users.zebradil = {
        imports = (builtins.attrValues self.modules.homeManager) ++ [ self.modules.generic.home-zebradil ];
      };

      sops.secrets."u2f_keys/${config.networking.hostName}" = lib.mkIf config.znix.fido.enable {
        path = "/home/zebradil/.config/Yubico/u2f_keys";
        owner = "zebradil";
        mode = "0400";
      };
    };
}
