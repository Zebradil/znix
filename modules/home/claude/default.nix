{ lib, inputs, ... }:
let
  # Renovate-sweep permissions: read + red-agent fix/merge after CI passes.
  # Shared across hosts via flake.lib.claude (see below).
  renovatePermissions = [
    "Bash(gh pr list:*)"
    "Bash(gh pr checks:*)"
    "Bash(gh pr view:*)"
    "Bash(gh run view:*)"
    "Bash(gh pr comment:*)"
    "Bash(git fetch:*)"
    "Bash(git worktree:*)"
    "Bash(git add:*)"
    "Bash(git commit:*)"
    "Bash(git push:*)"
    "Bash(gh pr review:*)"
    "Bash(gh pr merge:*)"
    "Bash(nix flake check)"
    "Bash(nixos-rebuild build:*)"
    "Bash(darwin-rebuild build:*)"
  ];

  claudeOptionsModule =
    { lib, ... }:
    {
      options.znix.claude = {
        assetsRoot = lib.mkOption {
          type = lib.types.path;
          default = inputs.self + "/ai";
          description = ''
            Root path of the shared, tool-agnostic AI agent asset tree
            (AGENTS.md, skills/, agents/, commands/). Lives at the repo root
            (ai/), not under any single tool's module. Override to point at a
            flake input for an out-of-repo source.
          '';
        };

        extraSkillRoots = lib.mkOption {
          type = lib.types.listOf lib.types.path;
          default = [
            (inputs.self + "/vendor/mattpocock-skills/engineering")
            (inputs.self + "/vendor/mattpocock-skills/productivity")
          ];
          description = ''
            Extra directories whose immediate children are skill bundles, merged
            into each profile's skills/ alongside assetsRoot/skills. Defaults to
            the vendir-managed mattpocock/skills tree (see vendir.yml).
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

        defaultSettings = lib.mkOption {
          type = lib.types.attrs;
          default = {
            agentPushNotifEnabled = true;
            editorMode = "vim";
            # LSP tool is opt-in even on 2.x; servers wired via the local
            # znix-lsp @skills-dir plugin (see znix.lsp.servers), not a marketplace.
            env.ENABLE_LSP_TOOL = "1";
            model = "opusplan";
            permissions.defaultMode = "auto";
            remoteControlAtStartup = true;
            tui = "fullscreen";
            verbose = true;
          };
          description = ''
            settings.json defaults merged under every profile's settings.
            Per-profile settings win (deep merge via lib.recursiveUpdate).
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

                  ponytail = lib.mkEnableOption "ponytail hooks/skills/commands for this profile";

                  worklog = lib.mkEnableOption "worklog Stop hook for this profile";

                  worklogName = lib.mkOption {
                    type = lib.types.str;
                    default = name;
                    description = ''
                      Label written into worklog records and used as the worklog
                      subdir. Collapse related profiles to a shared name (e.g. set
                      both company profiles to "trv") so they share one worklog.
                    '';
                  };

                  worklogSources = lib.mkOption {
                    default = [ ];
                    description = ''
                      Extra standup data sources (besides the worklog itself) the
                      /standup skill fetches for this profile. Each cmd is a shell
                      command emitting raw data; `{{since}}` is replaced with the
                      last-standup timestamp.
                    '';
                    type = lib.types.listOf (
                      lib.types.submodule {
                        options = {
                          name = lib.mkOption {
                            type = lib.types.str;
                            description = "Section label in the standup report";
                          };
                          cmd = lib.mkOption {
                            type = lib.types.str;
                            description = "Shell command emitting raw data; {{since}} → last-standup timestamp";
                          };
                        };
                      }
                    );
                  };

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
  flake.lib.claude = {
    inherit renovatePermissions;

    # Shared `personal` profile skeleton. Hosts pass only their settings deltas;
    # base settings come from znix.claude.defaultSettings.
    mkPersonalProfile =
      {
        settings ? { },
      }:
      {
        enable = true;
        caveman = true;
        ponytail = true;
        configDir = ".config/personal-claude";
        command = "claude";
        settings = lib.recursiveUpdate {
          permissions.allow = renovatePermissions;
        } settings;
      };
  };

  flake.modules = {
    # znix.lsp.servers feeds both the Claude plugin and opencode renderers, so
    # pull it in wherever claude is imported.
    nixos.claude.imports = [
      claudeOptionsModule
      inputs.self.modules.nixos.lsp
    ];
    darwin.claude.imports = [
      claudeOptionsModule
      inputs.self.modules.darwin.lsp
    ];

    # Home scope needs the same schema so standalone home configs (no osConfig)
    # can set/read znix.claude.* directly. Registered as its own swept module so
    # every home config gets it, mirroring homeManager.lsp.
    homeManager.claude-options = claudeOptionsModule;

    homeManager.claude =
      {
        lib,
        config,
        pkgs,
        ...
      }:
      let
        profiles = config.znix.claude.profiles or { };
        enabled = lib.filterAttrs (_: p: p.enable) profiles;
        assetsRoot = config.znix.claude.assetsRoot;
        extraSkillRoots = config.znix.claude.extraSkillRoots or [ ];

        # Local LSP plugin, loaded in-place as `znix-lsp@skills-dir` (no
        # marketplace, so it works on company profiles too). See znix.lsp.servers.
        lspServers = config.znix.lsp.servers or { };
        mkClaudeLsp =
          srv:
          {
            command = srv.command;
            extensionToLanguage = srv.extensions;
          }
          // lib.optionalAttrs (srv.args != [ ]) { inherit (srv) args; }
          // lib.optionalAttrs (srv.settings != { }) { inherit (srv) settings; };
        lspPluginJson = pkgs.writeText "znix-lsp-plugin.json" (
          builtins.toJSON {
            name = "znix-lsp";
            version = "0.0.0";
            lspServers = lib.mapAttrs (_: mkClaudeLsp) lspServers;
          }
        );
        knowRoot =
          if config.znix.claude.knowRoot != null then
            config.znix.claude.knowRoot
          else
            "${config.home.homeDirectory}/code/github.com/zebradil/know";

        mkWrapper =
          _: profile:
          pkgs.writeShellScriptBin profile.command ''
            set -euo pipefail
            export CLAUDE_CONFIG_DIR="$HOME/${profile.configDir}"
            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (k: v: ''export ${k}="$(${v})"'') profile.runtimeEnv
            )}
            exec ${pkgs.claude-code}/bin/claude "$@"
          '';

        cavemanEnabled = config.znix.claude.caveman.enable or false;
        ponytailEnabled = config.znix.claude.ponytail.enable or false;
        worklogEnabled = config.znix.claude.worklog.enable or false;

        mkNodeHook = configDir: script: {
          type = "command";
          command = ''${pkgs.nodejs}/bin/node "$HOME/${configDir}/hooks/${script}"'';
          timeout = 5;
        };

        mkCavemanHooks =
          profile:
          lib.optionalAttrs (profile.caveman && cavemanEnabled) {
            SessionStart = [ { hooks = [ (mkNodeHook profile.configDir "caveman-activate.js") ]; } ];
            UserPromptSubmit = [ { hooks = [ (mkNodeHook profile.configDir "caveman-mode-tracker.js") ]; } ];
          };

        mkPonytailHooks =
          profile:
          lib.optionalAttrs (profile.ponytail && ponytailEnabled) {
            SessionStart = [ { hooks = [ (mkNodeHook profile.configDir "ponytail-activate.js") ]; } ];
            UserPromptSubmit = [ { hooks = [ (mkNodeHook profile.configDir "ponytail-mode-tracker.js") ]; } ];
            SubagentStart = [ { hooks = [ (mkNodeHook profile.configDir "ponytail-subagent.js") ]; } ];
          };

        # worklog needs argv (the sources.json path), so it can't use the
        # zero-arg mkNodeHook helper — build the command inline.
        mkWorklogHooks =
          profile:
          lib.optionalAttrs (profile.worklog && worklogEnabled) {
            Stop = [
              {
                hooks = [
                  {
                    type = "command";
                    command = ''${pkgs.nodejs}/bin/node "$HOME/${profile.configDir}/hooks/worklog-record.js" "$HOME/${profile.configDir}/worklog-sources.json"'';
                    timeout = 5;
                  }
                ];
              }
            ];
          };

        defaultSettings = config.znix.claude.defaultSettings;

        mkSettingsFile =
          name: profile:
          let
            effective = lib.recursiveUpdate defaultSettings profile.settings;
            base = effective.hooks or { };
            # Each addon contributes per-event hook lists; fold them onto the
            # base settings, concatenating where events overlap (e.g. both
            # caveman and ponytail register SessionStart).
            contributions = [
              (mkCavemanHooks profile)
              (mkPonytailHooks profile)
              (mkWorklogHooks profile)
            ];
            addContribution = acc: c: acc // lib.mapAttrs (k: v: (acc.${k} or [ ]) ++ v) c;
            mergedHooks = lib.foldl' addContribution base contributions;
            finalSettings =
              (removeAttrs effective [ "hooks" ])
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

        # Symlink skill bundles from extraSkillRoots into the profile's skills/,
        # honouring the same exclude list as the skills category.
        mkExtraSkillFiles =
          profile:
          let
            excluded = profile.excludeAssets.skills;
            stem = n: lib.removeSuffix ".md" n;
            mkRoot =
              root:
              if !builtins.pathExists root then
                { }
              else
                lib.mapAttrs' (
                  entryName: _type:
                  lib.nameValuePair "${profile.configDir}/skills/${entryName}" {
                    source = "${root}/${entryName}";
                  }
                ) (lib.filterAttrs (n: _: !lib.elem (stem n) excluded) (builtins.readDir root));
          in
          lib.foldl' (acc: root: acc // mkRoot root) { } extraSkillRoots;

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
          home.packages =
            lib.optional (!lib.elem "claude" wrapperNames) pkgs.claude-code ++ wrappers ++ helperScripts;
        }

        {
          home = {
            sessionVariables.KNOW_ROOT = knowRoot;

            file = lib.mkMerge (
              lib.mapAttrsToList (
                _: profile:
                (
                  {
                    "${profile.configDir}/CLAUDE.md".source = "${assetsRoot}/AGENTS.md";
                    "${profile.configDir}/statusline-command.sh".source = "${assetsRoot}/statusline-command.sh";
                  }
                  // lib.optionalAttrs (lspServers != { }) {
                    "${profile.configDir}/skills/znix-lsp/.claude-plugin/plugin.json".source = lspPluginJson;
                  }
                )
                // mkCategoryFiles profile "skills"
                // mkExtraSkillFiles profile
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
            persistence."/persist" = lib.mkIf (config.znix.impermanence.enable or false) {
              directories = lib.mapAttrsToList (_: profile: profile.configDir) enabled;
            };
          };
        }
      ];
  };
}
