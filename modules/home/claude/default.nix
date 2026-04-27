_:
let
  claudeOptionsModule =
    { lib, ... }:
    {
      options.znix.claude.profiles = lib.mkOption {
        default = { };
        description = "Claude Code profiles, keyed by name";
        type = lib.types.attrsOf (
          lib.types.submodule (
            { name, ... }:
            {
              options = {
                enable = lib.mkEnableOption "claude profile ${name}";

                configDir = lib.mkOption {
                  type = lib.types.str;
                  description = "Config directory path relative to $HOME";
                };

                command = lib.mkOption {
                  type = lib.types.str;
                  default = name;
                  description = "Wrapper script name placed on PATH";
                };

                runtimeEnv = lib.mkOption {
                  type = lib.types.attrsOf lib.types.str;
                  default = { };
                  description = "Env var name → shell snippet whose stdout becomes the value";
                };

                settings = lib.mkOption {
                  type = lib.types.attrs;
                  default = { };
                  description = "settings.json content; statusLine is computed automatically";
                };
              };
            }
          )
        );
      };
    };
in
{
  flake.modules.nixos.claude = claudeOptionsModule;
  flake.modules.darwin.claude = claudeOptionsModule;

  flake.modules.homeManager.claude =
    {
      lib,
      osConfig,
      pkgs,
      config,
      ...
    }:
    let
      profiles = osConfig.znix.claude.profiles or { };
      enabled = lib.filterAttrs (_: p: p.enable) profiles;

      mkWrapper =
        name: profile:
        pkgs.writeShellScriptBin profile.command ''
          set -euo pipefail
          export CLAUDE_CONFIG_DIR="$HOME/${profile.configDir}"
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (k: v: ''export ${k}="$(${v})"'') profile.runtimeEnv
          )}
          exec ${pkgs.claude-code}/bin/claude "$@"
        '';

      mkSettingsFile =
        name: profile:
        pkgs.writeText "claude-${name}-settings.json" (
          builtins.toJSON (
            profile.settings
            // {
              statusLine = {
                type = "command";
                command = "bash ${config.home.homeDirectory}/${profile.configDir}/statusline-command.sh";
              };
            }
          )
        );

      wrappers = lib.mapAttrsToList mkWrapper enabled;
      wrapperNames = lib.mapAttrsToList (_: p: p.command) enabled;
    in
    lib.mkMerge [
      {
        home.packages = [
          pkgs.claude-monitor
        ]
        ++ lib.optional (!lib.elem "claude" wrapperNames) pkgs.claude-code
        ++ wrappers;
      }

      {
        home.file = lib.mkMerge (
          lib.mapAttrsToList (name: profile: {
            "${profile.configDir}/CLAUDE.md".source = ./assets/CLAUDE.md;
            "${profile.configDir}/statusline-command.sh".source = ./assets/statusline-command.sh;
          }) enabled
        );

        home.activation = lib.mkMerge (
          lib.mapAttrsToList (
            name: profile:
            let
              settingsFile = mkSettingsFile name profile;
            in
            {
              "copyClaudeSettings-${name}" = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                $DRY_RUN_CMD mkdir -p "$HOME/${profile.configDir}"
                $DRY_RUN_CMD install -m 0644 ${settingsFile} "$HOME/${profile.configDir}/settings.json"
              '';
            }
          ) enabled
        );

        home.persistence."/persist" = lib.mkIf (osConfig.znix.impermanence.enable or false) {
          directories = lib.mapAttrsToList (_: profile: profile.configDir) enabled;
        };
      }
    ];
}
