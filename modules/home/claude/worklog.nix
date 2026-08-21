{ inputs, ... }:
let
  worklogOptionsModule =
    { lib, ... }:
    {
      options.znix.claude.worklog = {
        enable = lib.mkEnableOption "worklog Stop hook for claude profiles";
        default = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            worklogName that env-less tools (opencode, cursor) fall back to when
            worklog-prep runs without --profile and without CLAUDE_CONFIG_DIR.
            May stay null when all enabled profiles share one worklogName.
          '';
        };
      };
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

        # One sources.json per worklogName. Profiles sharing a worklogName (the
        # two company profiles) also share sources, so last-wins is safe.
        cfgByName = lib.foldlAttrs (
          acc: name: profile:
          acc // { ${profile.worklogName} = sourcesJson name profile; }
        ) { } enabled;
        worklogNames = builtins.attrNames cfgByName;
        defaultCfg =
          let
            name =
              if worklogCfg.default or null != null then
                worklogCfg.default
              else if builtins.length worklogNames == 1 then
                builtins.head worklogNames
              else
                throw "znix.claude.worklog.default must name one of: ${toString worklogNames}";
          in
          cfgByName.${name}
            or (throw "znix.claude.worklog.default = ${name} matches no enabled profile's worklogName (${toString worklogNames})");

        # Deterministic half of the /standup and /weekly skills, on PATH so it
        # works from any tool. Config resolution: explicit --profile, else the
        # invoking claude profile ($CLAUDE_CONFIG_DIR — keeps personal claude on
        # personal data), else the host default worklog for env-less tools.
        worklogPrep = pkgs.writeShellScriptBin "worklog-prep" ''
          if [ "''${1:-}" = "--profile" ]; then
            case "''${2:-}" in
              ${lib.concatMapStringsSep "\n    " (n: "${n}) cfg=${cfgByName.${n}} ;;") worklogNames}
              *)
                echo "unknown worklog profile ''${2:-}; available: ${toString worklogNames}" >&2
                exit 1
                ;;
            esac
            shift 2
          elif [ -n "''${CLAUDE_CONFIG_DIR:-}" ]; then
            cfg="$CLAUDE_CONFIG_DIR/worklog-sources.json"
          else
            cfg=${defaultCfg}
          fi
          exec ${pkgs.nodejs}/bin/node ${./worklog/worklog-prep.js} --config "$cfg" "$@"
        '';
      in
      lib.mkIf (worklogCfg.enable && enabled != { }) {
        home.packages = [ worklogPrep ];

        home.file = lib.mkMerge (
          lib.mapAttrsToList (name: profile: {
            "${profile.configDir}/hooks/worklog-record.js".source = ./worklog/worklog-record.js;
            "${profile.configDir}/worklog-sources.json".source = sourcesJson name profile;
          }) enabled
        );

        home.persistence."/persist" = lib.mkIf (config.znix.impermanence.enable or false) {
          directories = [ ".local/state/znix/worklog" ];
        };
      };
  };
}
