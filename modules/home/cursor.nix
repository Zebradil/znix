{ inputs, ... }:
{
  flake.modules.homeManager.cursor =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.znix.cursor;
      assetsRoot = config.znix.claude.assetsRoot;
      extraSkillRoots = config.znix.claude.extraSkillRoots;
      cavemanSrc = builtins.path {
        path = inputs.self + "/vendor/caveman";
        name = "znix-vendor-caveman";
      };
      ponytailSrc = builtins.path {
        path = inputs.self + "/vendor/ponytail";
        name = "znix-vendor-ponytail";
      };
      pluginDir = ".cursor/plugins/local/znix";

      mkSkillFiles =
        srcDir: excluded:
        lib.optionalAttrs (builtins.pathExists srcDir) (
          lib.mapAttrs'
            (
              name: type:
              lib.nameValuePair ".cursor/skills/${name}" {
                source = "${srcDir}/${name}";
              }
            )
            (
              lib.filterAttrs (name: type: type == "directory" && !lib.elem name excluded) (
                builtins.readDir srcDir
              )
            )
        );

      mkCursorMd =
        src:
        let
          name = builtins.unsafeDiscardStringContext (baseNameOf src);
          file = builtins.path {
            path = src;
            inherit name;
          };
        in
        pkgs.runCommand "cursor-${name}" { } ''
          ${pkgs.gnused}/bin/sed -E -e '/^(mode|tools|model|allowed-tools):/d' -e 's/ \(Task tool\)//' ${file} > $out
        '';

      pluginManifest = pkgs.writeText "znix-cursor-plugin.json" (
        builtins.toJSON {
          name = "znix";
          version = "0.1.0";
          displayName = "znix";
          description = "Shared znix agent configuration";
        }
      );
      instructionsRule = pkgs.writeText "znix-cursor-instructions.mdc" ''
        ---
        description: Shared znix agent instructions
        alwaysApply: true
        ---

        ${builtins.readFile "${assetsRoot}/AGENTS.md"}
      '';
      cavemanRule = pkgs.writeText "znix-cursor-caveman.mdc" ''
        ---
        description: Caveman mode
        alwaysApply: true
        ---

        ${builtins.readFile "${cavemanSrc}/src/rules/caveman-activate.md"}
      '';
      agent = pkgs.writeShellScriptBin "agent" ''
        exec ${pkgs.cursor-cli}/bin/cursor-agent --plugin-dir "$HOME/${pluginDir}" "$@"
      '';
      # Copy just this file into the store: embedding a subpath of assetsRoot
      # would pin the whole flake source. Wrap PATH so Cursor's spawn (no login
      # shell) still finds jq and git.
      znixStatusline = builtins.path {
        path = assetsRoot + "/statusline-command.sh";
        name = "znix-statusline-command.sh";
      };
      statusline = pkgs.writeShellScript "cursor-statusline" ''
        export PATH="${
          lib.makeBinPath [
            pkgs.git
            pkgs.jq
          ]
        }:$PATH"
        exec ${pkgs.bash}/bin/bash ${znixStatusline}
      '';
    in
    {
      options.znix.cursor.enable = lib.mkEnableOption "Cursor agent configuration";

      config = lib.mkIf cfg.enable {
        home.packages = [
          pkgs.code-cursor
          pkgs.cursor-cli
          agent
        ];

        home.file = lib.mkMerge [
          (mkSkillFiles "${assetsRoot}/skills" [
            "save-convo"
            "save-note"
            "export-session"
            "standup"
            "weekly"
            "kick-pr-copilot"
          ])
          (lib.mkMerge (map (root: mkSkillFiles root [ ]) extraSkillRoots))
          (mkSkillFiles "${cavemanSrc}/skills" [
            "cavecrew"
            "caveman-compress"
            "caveman-stats"
          ])
          (mkSkillFiles "${ponytailSrc}/skills" [ ])
          {
            "${pluginDir}/.cursor-plugin/plugin.json".source = pluginManifest;
            "${pluginDir}/rules/znix.mdc".source = instructionsRule;
            "${pluginDir}/rules/caveman.mdc".source = cavemanRule;
            "${pluginDir}/rules/ponytail.mdc".source = "${ponytailSrc}/.cursor/rules/ponytail.mdc";
            "${pluginDir}/agents/renovate-red.md".source = mkCursorMd (assetsRoot + "/agents/renovate-red.md");
            "${pluginDir}/commands/renovate-sweep.md".source = mkCursorMd (
              assetsRoot + "/commands/renovate-sweep.md"
            );
            ".cursor/statusline-command.sh".source = statusline;
          }
        ];

        # cli-config.json is Cursor-owned (auth, model picker). Merge only
        # statusLine so a home switch keeps pointing at the wrapped script.
        home.activation.cursorStatusLine = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          cfg="$HOME/.cursor/cli-config.json"
          cmd="$HOME/.cursor/statusline-command.sh"
          if [[ -f "$cfg" ]]; then
            if current=$(${pkgs.jq}/bin/jq -r '.statusLine.command // empty' "$cfg" 2>/dev/null); then
              if [[ "$current" != "$cmd" ]]; then
                echo "setting Cursor CLI statusLine.command to $cmd"
                if [[ ! -v DRY_RUN ]]; then
                  tmp=$(mktemp)
                  ${pkgs.jq}/bin/jq --arg cmd "$cmd" \
                    '.statusLine = {type: "command", command: $cmd}' "$cfg" > "$tmp"
                  mv "$tmp" "$cfg"
                fi
              fi
            else
              echo "skipping Cursor statusLine merge: $cfg is not valid JSON"
            fi
          fi
        '';

        home.persistence."/persist" = lib.mkIf (config.znix.impermanence.enable or false) {
          directories = [ ".cursor" ];
        };
      };
    };
}
