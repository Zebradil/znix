_: {
  flake.modules.homeManager.opencode =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      profiles = osConfig.znix.claude.profiles or { };
      personal = profiles.personal or null;
      # Mirror the `personal` Claude profile into opencode's single global
      # config dir. opencode's auto-compat only scans ~/.claude, but znix writes
      # to ~/.config/personal-claude, so the assets are wired explicitly here.
      ocEnable = personal != null && personal.enable;
      cavemanOn = (osConfig.znix.claude.caveman.enable or false) && personal != null && personal.caveman;
      ponytailOn =
        (osConfig.znix.claude.ponytail.enable or false) && personal != null && personal.ponytail;
      assetsRoot = osConfig.znix.claude.assetsRoot;
      extraSkillRoots = osConfig.znix.claude.extraSkillRoots or [ ];

      # Strip Claude-only frontmatter opencode rejects: `tools: [array]` and a
      # bare `model: haiku` (opencode wants `provider/model`). Mirrors caveman's
      # stripOpencodeAgentTools (bin/lib/opencode-agent.js).
      mkOpencodeMd =
        src:
        pkgs.runCommand "oc-${baseNameOf (toString src)}" { } ''
          ${pkgs.gnused}/bin/sed -E '/^(tools|model|allowed-tools):/d' ${src} > $out
        '';

      # Symlink every entry of a source dir (skills: dirs are skills, the loose
      # _pkb-routing.md sibling rides along for relative references).
      mkSymlinkEntries =
        relBase: srcDir:
        lib.optionalAttrs (builtins.pathExists srcDir) (
          lib.mapAttrs' (name: _: lib.nameValuePair "${relBase}/${name}" { source = "${srcDir}/${name}"; }) (
            builtins.readDir srcDir
          )
        );

      # Transform each *.md in a source dir through mkOpencodeMd, then symlink.
      mkTransformedMds =
        relBase: srcDir:
        lib.optionalAttrs (builtins.pathExists srcDir) (
          lib.mapAttrs' (
            name: _: lib.nameValuePair "${relBase}/${name}" { source = mkOpencodeMd "${srcDir}/${name}"; }
          ) (lib.filterAttrs (n: _: lib.hasSuffix ".md" n) (builtins.readDir srcDir))
        );

      # Same server map as the Claude plugin, rendered into opencode's native
      # `lsp` schema (command is an array, extensions a flat list). See
      # znix.lsp.servers. Store-path commands + OPENCODE_DISABLE_LSP_DOWNLOAD
      # keep opencode from fetching servers on its own.
      lspServers = osConfig.znix.lsp.servers or { };
      mkOcLsp =
        srv:
        {
          command = [ srv.command ] ++ srv.args;
          extensions = builtins.attrNames srv.extensions;
        }
        // lib.optionalAttrs (srv.settings != { }) { initialization = srv.settings; };

      ocSettings = {
        "$schema" = "https://opencode.ai/config.json";
        plugin =
          lib.optional cavemanOn "./plugins/caveman/plugin.js"
          ++ lib.optional ponytailOn "./plugins/ponytail/ponytail.mjs";
      }
      // lib.optionalAttrs (lspServers != { }) { lsp = lib.mapAttrs (_: mkOcLsp) lspServers; };
      ocSettingsFile = pkgs.writeText "opencode.json" (builtins.toJSON ocSettings);
    in
    lib.mkMerge [
      {
        home.packages = [ pkgs.opencode ];
        # Servers come from Nix (store-path commands); never auto-download.
        home.sessionVariables.OPENCODE_DISABLE_LSP_DOWNLOAD = "true";
      }

      (lib.mkIf (osConfig.znix.impermanence.enable or false) {
        home.persistence."/persist".directories = [
          ".config/opencode"
          ".local/share/opencode"
          ".local/state/opencode"
        ];
      })

      (lib.mkIf ocEnable {
        home.file = lib.mkMerge [
          (mkSymlinkEntries ".config/opencode/skills" "${assetsRoot}/skills")
          (lib.mkMerge (map (mkSymlinkEntries ".config/opencode/skills") extraSkillRoots))
          (mkTransformedMds ".config/opencode/agents" "${assetsRoot}/agents")
          (mkTransformedMds ".config/opencode/commands" "${assetsRoot}/commands")
          # Global instructions. When caveman is on, caveman.nix composes AGENTS.md
          # (instructions + ruleset) instead, so guard against a double definition.
          (lib.optionalAttrs (!cavemanOn) {
            ".config/opencode/AGENTS.md".source = "${assetsRoot}/AGENTS.md";
          })
        ];

        # Install opencode.json as a real file (not a store symlink): opencode
        # may rewrite its own config. Mirrors copyClaudeSettings.
        home.activation.copyOpencodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD mkdir -p "$HOME/.config/opencode"
          $DRY_RUN_CMD install -m 0644 ${ocSettingsFile} "$HOME/.config/opencode/opencode.json"
        '';
      })
    ];
}
