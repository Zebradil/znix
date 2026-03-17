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

  # Declare home.persistence stub option for Darwin, where the impermanence module is not available.
  flake.modules.homeManager.impermanence =
    { lib, pkgs, ... }:
    {
      options = lib.optionalAttrs pkgs.stdenv.isDarwin {
        home.persistence = lib.mkOption {
          type = lib.types.anything;
          default = { };
        };
      };
    };

  # Declare darwin.impermanence stub module, which just provides the option path for the home module.
  flake.modules.darwin.impermanence =
    { lib, ... }:
    {
      options.znix.impermanence.enable = lib.mkEnableOption "opt-in persistence";
      # config intentionally left empty — just provides the option path
    };
}
