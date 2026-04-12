_: {
  flake.modules.homeManager._1password =
    {
      pkgs,
      lib,
      config,
      osConfig,
      isDarwin,
      ...
    }:
    let
      base =
        let
          allowedSignersFile = pkgs.writeText "allowed-signers" ''
            ${config.znix.user.email} ${config.sshPublicKey}
          '';
        in
        {
          programs.git = {
            signing = {
              format = "ssh";
              key = config.sshPublicKey;
              signByDefault = true;
              signer = "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}";
            };
            settings."gpg.ssh".allowedSignersFile = toString allowedSignersFile;
          };
        };

      darwin = {
        home.packages = [ pkgs._1password-cli ];
      };

      nixos = {
        programs.ssh.matchBlocks."*".identityAgent = "~/.1password/agent.sock";
        wayland.windowManager.hyprland.settings.exec-once = [ "1password --silent" ];
      };

      impermanence = lib.mkIf osConfig.znix.impermanence.enable {
        home.persistence."/persist".directories = [ ".config/1Password" ];
      };

    in
    lib.mkMerge (
      if isDarwin then
        [
          base
          darwin
        ]
      else
        [
          base
          nixos
          impermanence
        ]
    );

  flake.modules.nixos._1password =
    { config, lib, ... }:
    {
      programs._1password.enable = true;
      programs._1password-gui = {
        enable = true;
        polkitPolicyOwners = builtins.attrNames (lib.filterAttrs (_: u: u.isNormalUser) config.users.users);
      };
    };
}
