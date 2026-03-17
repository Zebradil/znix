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

  # Declare home.persistence stub option only on Darwin.
  # Using isDarwin (passed via extraSpecialArgs) instead of pkgs.stdenv.isDarwin avoids
  # infinite recursion caused by accessing pkgs inside the options declaration phase.
  # On NixOS the real home.persistence option is provided by the impermanence module
  # (auto-added to home-manager.sharedModules by inputs.impermanence.nixosModules.impermanence).
  flake.modules.homeManager.impermanence =
    { lib, isDarwin, ... }:
    lib.optionalAttrs isDarwin {
      options.home.persistence = lib.mkOption {
        type = lib.types.anything;
        default = { };
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
