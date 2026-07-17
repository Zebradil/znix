{ inputs, ... }:
let
  worklogOptionsModule =
    { lib, ... }:
    {
      options.znix.claude.worklog.enable = lib.mkEnableOption "worklog Stop hook for claude profiles";
    };
in
{
  flake.modules = {
    nixos.claude-worklog = worklogOptionsModule;
    darwin.claude-worklog = worklogOptionsModule;
    # Home scope needs the option declared too, so home profiles can set
    # znix.claude.worklog.enable directly (no osConfig). Swept like claude-options.
    homeManager.claude-worklog-options = worklogOptionsModule;

    homeManager.claude-worklog =
      {
        lib,
        config,
        pkgs,
        ...
      }:
      let
        worklogCfg = config.znix.claude.worklog or { enable = false; };
        allProfiles = config.znix.claude.profiles or { };
        enabled = lib.filterAttrs (_: p: p.enable && worklogCfg.enable && p.worklog) allProfiles;

        worklogBase = "${config.home.homeDirectory}/.local/state/znix/worklog";
        worklogDir = profile: "${worklogBase}/${profile.worklogName}";

        # Deterministic half of the /standup and /weekly skills. A static markdown
        # skill can't interpolate a node store path the way the Stop hook does, so
        # bake it into a wrapper the skill invokes as $CLAUDE_CONFIG_DIR/hooks/worklog-prep.
        worklogPrep = pkgs.writeShellScriptBin "worklog-prep" ''
          exec ${pkgs.nodejs}/bin/node ${./worklog/worklog-prep.js} "$@"
        '';

        # Single source of truth read by BOTH the Stop hook (for the output dir +
        # profile label) and the /standup skill (for the source fetch commands).
        sourcesJson =
          name: profile:
          pkgs.writeText "worklog-sources-${name}.json" (
            builtins.toJSON {
              profile = profile.worklogName;
              worklog_dir = worklogDir profile;
              sources = map (
                s:
                { inherit (s) name cmd; } // lib.optionalAttrs (s.instruction != null) { inherit (s) instruction; }
              ) profile.worklogSources;
            }
          );
      in
      lib.mkIf (worklogCfg.enable && enabled != { }) {
        home.file = lib.mkMerge (
          lib.mapAttrsToList (name: profile: {
            "${profile.configDir}/hooks/worklog-record.js".source = ./worklog/worklog-record.js;
            "${profile.configDir}/hooks/worklog-prep".source = "${worklogPrep}/bin/worklog-prep";
            "${profile.configDir}/worklog-sources.json".source = sourcesJson name profile;
          }) enabled
        );

        home.persistence."/persist" = lib.mkIf (config.znix.impermanence.enable or false) {
          directories = [ ".local/state/znix/worklog" ];
        };
      };
  };
}
