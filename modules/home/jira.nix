_: {
  # jira-cli-go with a declaratively-rendered Cloud config. Swept into every
  # home config via mkHomeManager; inert until a profile sets znix.jira.enable.
  flake.modules.homeManager.jira =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.znix.jira;
      yaml = pkgs.formats.yaml { };
    in
    {
      options.znix.jira = {
        enable = lib.mkEnableOption "jira-cli-go with a rendered Cloud config";
        server = lib.mkOption {
          type = lib.types.str;
          example = "https://acme.atlassian.net";
          description = "Jira Cloud base URL.";
        };
        login = lib.mkOption {
          type = lib.types.str;
          description = ''
            Atlassian account email — the basic-auth login. The API token is
            supplied out-of-band via the JIRA_API_TOKEN env var at call time,
            never written to the store.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        home.packages = [ pkgs.jira-cli-go ];

        # jira-cli reads $XDG_CONFIG_HOME/.jira/.config.yml (falls back to
        # ~/.config, incl. on macOS). project/board are omitted on purpose:
        # standup passes an explicit --jql, which needs neither.
        xdg.configFile.".jira/.config.yml".source = yaml.generate "jira-config.yml" {
          installation = "Cloud";
          server = cfg.server;
          login = cfg.login;
          auth_type = "basic";
        };
      };
    };
}
