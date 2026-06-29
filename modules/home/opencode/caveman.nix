{ inputs, ... }:
{
  flake.modules.homeManager.opencode-caveman =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      profiles = osConfig.znix.claude.profiles or { };
      personal = profiles.personal or null;
      cavemanOn = (osConfig.znix.claude.caveman.enable or false) && personal != null && personal.caveman;
      assetsRoot = osConfig.znix.claude.assetsRoot;
      cavemanSrc = inputs.self + "/vendor/caveman";

      pluginDir = ".config/opencode/plugins/caveman";
      ocPluginSrc = "${cavemanSrc}/src/plugins/opencode";

      # Same frontmatter strip as opencode/default.nix — cavecrew agents target
      # Claude's `tools: [array]` schema, which opencode rejects.
      mkOpencodeMd =
        src:
        pkgs.runCommand "oc-${baseNameOf (toString src)}" { } ''
          ${pkgs.gnused}/bin/sed -E '/^(tools|model|allowed-tools):/d' ${src} > $out
        '';

      # Symlink every entry of a source dir under a relative dest dir.
      mkSymlinkEntries =
        relBase: srcDir:
        lib.mapAttrs' (name: _: lib.nameValuePair "${relBase}/${name}" { source = "${srcDir}/${name}"; }) (
          builtins.readDir srcDir
        );

      cavecrewAgents = [
        "cavecrew-investigator.md"
        "cavecrew-builder.md"
        "cavecrew-reviewer.md"
      ];

      # Compose global instructions + the always-on caveman ruleset so both load.
      agentsMd = pkgs.writeText "opencode-AGENTS.md" (
        builtins.readFile "${assetsRoot}/CLAUDE.md"
        + "\n\n<!-- caveman-begin -->\n"
        + builtins.readFile "${cavemanSrc}/src/rules/caveman-activate.md"
        + "\n<!-- caveman-end -->\n"
      );
    in
    lib.mkIf cavemanOn {
      home.packages = [ pkgs.nodejs ];

      home.file = lib.mkMerge [
        # 1. Plugin dir. caveman-config.js is renamed to .cjs because the plugin
        #    dir is type:module — a bare .js sibling would be loaded as ESM.
        {
          "${pluginDir}/plugin.js".source = "${ocPluginSrc}/plugin.js";
          "${pluginDir}/package.json".source = "${ocPluginSrc}/package.json";
          "${pluginDir}/caveman-config.cjs".source = "${cavemanSrc}/src/hooks/caveman-config.js";
        }

        # 2. Caveman slash-command templates.
        (mkSymlinkEntries ".config/opencode/commands" "${ocPluginSrc}/commands")

        # 3. Caveman skills (auto-discovered SKILL.md).
        (mkSymlinkEntries ".config/opencode/skills" "${cavemanSrc}/skills")

        # 4. Cavecrew subagents, tools-stripped for opencode's schema.
        (lib.listToAttrs (
          map (
            f:
            lib.nameValuePair ".config/opencode/agents/${f}" {
              source = mkOpencodeMd "${cavemanSrc}/agents/${f}";
            }
          ) cavecrewAgents
        ))

        # 5. Global instructions + caveman ruleset (default.nix yields AGENTS.md
        #    to this module whenever caveman is on, so no collision).
        {
          ".config/opencode/AGENTS.md".source = agentsMd;
        }
      ];
    };
}
