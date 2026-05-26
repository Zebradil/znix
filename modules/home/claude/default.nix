_:
let
  claudeOptionsModule =
    { lib, ... }:
    {
      options.znix.claude = {
        assetsRoot = lib.mkOption {
          type = lib.types.path;
          default = ./assets;
          description = ''
            Root path of the shared Claude asset tree (CLAUDE.md, skills/, agents/, commands/).
            Override to point at a flake input for an out-of-repo source.
          '';
        };

        knowRoot = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Path to the user's PKB (personal knowledge base) repo on this host.
            When set, exported as KNOW_ROOT for shell sessions; the pkb-* helper
            scripts and the save-convo / save-note skills consume it.
          '';
        };

        profiles = lib.mkOption {
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

                  caveman = lib.mkEnableOption "caveman hooks/skills/commands for this profile";

                  excludeAssets = lib.mkOption {
                    default = { };
                    description = "Per-category asset names (without .md) to omit for this profile";
                    type = lib.types.submodule {
                      options = {
                        skills = lib.mkOption {
                          type = lib.types.listOf lib.types.str;
                          default = [ ];
                        };
                        agents = lib.mkOption {
                          type = lib.types.listOf lib.types.str;
                          default = [ ];
                        };
                        commands = lib.mkOption {
                          type = lib.types.listOf lib.types.str;
                          default = [ ];
                        };
                      };
                    };
                  };
                };
              }
            )
          );
        };
      };
    };
in
{
  flake.modules = {
    nixos.claude = claudeOptionsModule;
    darwin.claude = claudeOptionsModule;

    homeManager.claude =
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
        assetsRoot = osConfig.znix.claude.assetsRoot;
        knowRoot =
          if osConfig.znix.claude.knowRoot != null then
            osConfig.znix.claude.knowRoot
          else
            "${config.home.homeDirectory}/code/github.com/zebradil/know";

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

        cavemanEnabled = osConfig.znix.claude.caveman.enable or false;

        mkCavemanHook = configDir: script: {
          type = "command";
          command = ''${pkgs.nodejs}/bin/node "$HOME/${configDir}/hooks/${script}"'';
          timeout = 5;
        };

        mkCavemanHooks =
          profile:
          lib.optionalAttrs (profile.caveman && cavemanEnabled) {
            SessionStart = [ { hooks = [ (mkCavemanHook profile.configDir "caveman-activate.js") ]; } ];
            UserPromptSubmit = [ { hooks = [ (mkCavemanHook profile.configDir "caveman-mode-tracker.js") ]; } ];
          };

        mkSettingsFile =
          name: profile:
          let
            base = profile.settings.hooks or { };
            contributions = mkCavemanHooks profile;
            mergedHooks = base // lib.mapAttrs (k: v: (base.${k} or [ ]) ++ v) contributions;
            finalSettings =
              (builtins.removeAttrs profile.settings [ "hooks" ])
              // lib.optionalAttrs (mergedHooks != { }) { hooks = mergedHooks; }
              // {
                statusLine = {
                  type = "command";
                  command = "bash ${config.home.homeDirectory}/${profile.configDir}/statusline-command.sh";
                };
              };
          in
          pkgs.writeText "claude-${name}-settings.json" (builtins.toJSON finalSettings);

        # Enumerate entries in assets/<category>/, filtering excluded items.
        # Handles both foo.md files and foo/ bundle directories.
        mkCategoryFiles =
          profile: category:
          let
            dir = "${assetsRoot}/${category}";
            excluded = profile.excludeAssets.${category};
            stem = n: lib.removeSuffix ".md" n;
            entries = builtins.readDir dir;
            filtered = lib.filterAttrs (n: _: !lib.elem (stem n) excluded) entries;
          in
          if !builtins.pathExists dir then
            { }
          else
            lib.mapAttrs' (
              entryName: _type:
              lib.nameValuePair "${profile.configDir}/${category}/${entryName}" {
                source = "${dir}/${entryName}";
              }
            ) filtered;

        # Package every file in scripts/ as a standalone executable on PATH.
        helperScripts =
          let
            dir = ./scripts;
            entries = builtins.readDir dir;
          in
          lib.mapAttrsToList (
            name: _type: pkgs.writeShellScriptBin name (builtins.readFile "${dir}/${name}")
          ) entries;

        wrappers = lib.mapAttrsToList mkWrapper enabled;
        wrapperNames = lib.mapAttrsToList (_: p: p.command) enabled;
      in
      lib.mkMerge [
        {
          home.packages = [
            pkgs.claude-monitor
          ]
          ++ lib.optional (!lib.elem "claude" wrapperNames) pkgs.claude-code
          ++ wrappers
          ++ helperScripts;
        }

        {
          home = {
            sessionVariables.KNOW_ROOT = knowRoot;

            file = lib.mkMerge (
              lib.mapAttrsToList (
                name: profile:
                {
                  "${profile.configDir}/CLAUDE.md".source = "${assetsRoot}/CLAUDE.md";
                  "${profile.configDir}/statusline-command.sh".source = "${assetsRoot}/statusline-command.sh";
                }
                // mkCategoryFiles profile "skills"
                // mkCategoryFiles profile "agents"
                // mkCategoryFiles profile "commands"
              ) enabled
            );
            activation = lib.mkMerge (
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
            persistence."/persist" = lib.mkIf (osConfig.znix.impermanence.enable or false) {
              directories = lib.mapAttrsToList (_: profile: profile.configDir) enabled;
            };
          };
        }
      ];
  };
}
