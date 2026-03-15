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

      home-manager.useGlobalPkgs = true;
      home-manager.users.zebradil = {
        imports = (builtins.attrValues self.modules.homeManager) ++ [ ./_home.nix ];
        home = {
          username = "zebradil";
          homeDirectory = "/home/zebradil";
          stateVersion = "22.05";
          persistence."/persist" = lib.mkIf config.znix.impermanence.enable {
            directories = [
              ".local/share/nix" # trusted settings and repl history
              "code" # code projects

              "Documents"
              "Downloads"
              "Pictures"
              "Videos"
            ];
          };
        };
      };
    };
}
