_: {
  flake.modules.homeManager.alertmanager =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.znix.alertmanager;

      amAlerts = pkgs.writeShellApplication {
        name = "am-alerts";
        runtimeInputs = [
          pkgs.curl
          pkgs.jq
        ];
        runtimeEnv.AM_ALERTS_ENVIRONMENTS = pkgs.writeText "am-alerts-environments.json" (
          builtins.toJSON cfg.environments
        );
        text = builtins.readFile ./alertmanager/am-alerts.sh;
      };
    in
    {
      options.znix.alertmanager.environments = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              url = lib.mkOption {
                type = lib.types.str;
                description = "Alertmanager base URL, serving /api/v2.";
              };
              kubeContext = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "kubectl context of the cluster the alerts come from.";
              };
            };
          }
        );
        default = { };
        description = ''
          Named Alertmanager environments for `am-alerts` and the alerts skill.
          The name is what the user says ("critical alerts in <name>"); a
          company flake adds its own environments here.
        '';
      };

      # Unconditional: the alerts skill ships to every profile, and a bare URL
      # works without any environment configured.
      config.home.packages = [ amAlerts ];
    };
}
