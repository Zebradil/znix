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
    {
      home.packages = with pkgs; [
        _1password-gui
        _1password-cli
      ];

      home.persistence."/persist" = lib.mkIf (osConfig.znix.impermanence.enable or false) {
        directories = [ ".config/1Password" ];
      };

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
}
