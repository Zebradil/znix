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

  # Home-scope impermanence. Declares its own znix.impermanence.enable so home
  # modules can gate home.persistence on a HOME decision (config.znix...) instead
  # of peeking at the system via osConfig — which standalone home configs cannot do.
  #
  # Using isDarwin (passed via extraSpecialArgs) instead of pkgs.stdenv.isDarwin
  # avoids infinite recursion from accessing pkgs during option declaration.
  #
  # Where home.persistence comes from, by mode:
  #   - integrated NixOS (standalone=false, !isDarwin): injected via the NixOS
  #     impermanence module's sharedModules — do NOT declare it here (double-decl).
  #   - standalone (standalone=true, either OS): stub the option. Current
  #     impermanence has NO standalone-HM support — its home-manager.nix is a
  #     validation-only shim, and all bind-mounting lives in nixos.nix reading
  #     home-manager.users.*. So home persistence is owned entirely by the SYSTEM
  #     switch; standalone `home-manager switch` only re-links store files and
  #     must absorb the swept modules' home.persistence writes inertly.
  #   - Darwin (any mode): no impermanence exists; stub the option so reads don't error.
  flake.modules.homeManager.impermanence =
    {
      lib,
      isDarwin,
      standalone,
      ...
    }:
    {
      options.znix.impermanence.enable = lib.mkEnableOption "opt-in home persistence";
      imports = lib.optional (isDarwin || standalone) {
        options.home.persistence = lib.mkOption {
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
