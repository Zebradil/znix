{ ... }:
{
  flake.modules.homeManager._1password =
    {
      pkgs,
      lib,
      config,
      osConfig,
      ...
    }:
    let
      base = {
        home.packages = with pkgs; [
          _1password-gui
          _1password-cli
        ];

        programs.ssh = {
          extraConfig = ''
            Host *
                IdentityAgent ~/.1password/agent.sock
          '';
        };

        programs.git.settings = {
          gpg.format = "ssh";
          "gpg \"ssh\"" = {
            program = "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}";
          };

          user.signingKey = config.sshPublicKey.content;
        };
      };

      impermanence = lib.mkIf osConfig.znix.impermanence.enable {
        home.persistence."/persist".directories = [ ".config/1Password" ];
      };

    in
    lib.mkMerge [
      base
      impermanence
    ];
}
