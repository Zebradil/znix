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
      base = {
        programs.git.settings = {
          gpg.format = "ssh";
          "gpg \"ssh\"" = {
            program = "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}";
          };

          user.signingKey = config.sshPublicKey.content;
        };
      };

      darwin = {
        home.packages = [ pkgs._1password-cli ];
      };

      nixos = {
        programs.ssh.matchBlocks."*".identityAgent = "~/.1password/agent.sock";
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
