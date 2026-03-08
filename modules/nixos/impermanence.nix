{ inputs, ... }:
{
  flake-file.inputs.impermanence.url = "github:nix-community/impermanence";

  flake.modules.nixos.impermanence =
    {
      config,
      lib,
      ...
    }:
    {
      imports = [ inputs.impermanence.nixosModules.impermanence ];

      options.znix.impermanence.enable = lib.mkEnableOption "opt-in persistence";

      config = lib.mkIf config.znix.impermanence.enable {
        environment.persistence."/persist" = {
          files = [ "/etc/machine-id" ];
          directories = [
            "/var/lib/fprint"
            "/var/lib/systemd"
            "/var/lib/nixos"
            "/var/log"
            "/srv"
          ];
        };

        programs.fuse.userAllowOther = true;

        system.activationScripts.persistent-dirs.text =
          let
            mkHomePersist =
              user:
              lib.optionalString user.createHome ''
                mkdir -p /persist/${user.home}
                chown ${user.name}:${user.group} /persist/${user.home}
                chmod ${user.homeMode} /persist/${user.home}
              '';
            users = lib.attrValues config.users.users;
          in
          lib.concatLines (map mkHomePersist users);
      };
    };
}
