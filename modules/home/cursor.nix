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
          }
        ];

        home.persistence."/persist" = lib.mkIf (config.znix.impermanence.enable or false) {
          directories = [ ".cursor" ];
        };
      };
    };
}
