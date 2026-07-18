{ inputs, ... }:
let
  cavemanOptionsModule =
    { lib, ... }:
    {
      options.znix.claude.caveman.enable = lib.mkEnableOption "caveman hooks for claude profiles";
    };
in
{
  flake.modules = {
    nixos.claude-caveman = cavemanOptionsModule;
    darwin.claude-caveman = cavemanOptionsModule;
    # Home scope needs the option declared too, so home profiles can set
    # znix.claude.caveman.enable directly (no osConfig). Swept like claude-options.
    homeManager.claude-caveman-options = cavemanOptionsModule;

    homeManager.claude-caveman =
      {
        lib,
        config,
        pkgs,
        ...
      }:
      let
        cavemanCfg = config.znix.claude.caveman or { enable = false; };
        allProfiles = config.znix.claude.profiles or { };
        enabled = lib.filterAttrs (_: p: p.enable && cavemanCfg.enable && p.caveman) allProfiles;

        cavemanSrc = inputs.self + "/vendor/caveman";

        # The composed statusline (znix base + caveman/ponytail badges) lives in
        # modules/home/claude/statusline.nix so no single addon owns the file.
        mkDirFiles =
          profile: srcDir: destDir:
          lib.mapAttrs' (
            entryName: _type:
            lib.nameValuePair "${profile.configDir}/${destDir}/${entryName}" {
              source = "${srcDir}/${entryName}";
            }
          ) (builtins.readDir srcDir);
      in
      lib.mkIf (cavemanCfg.enable && enabled != { }) {
        home.packages = [ pkgs.nodejs ];

        home.file = lib.mkMerge (
          lib.mapAttrsToList (
            _: profile:
            (mkDirFiles profile "${cavemanSrc}/src/hooks" "hooks")
            // (mkDirFiles profile "${cavemanSrc}/skills" "skills")
            // (mkDirFiles profile "${cavemanSrc}/commands" "commands")
            # znix-owned SubagentStart hook — upstream caveman ships none, and it
            # can't live under vendor/caveman (vendir sync would wipe it).
            // {
              "${profile.configDir}/hooks/caveman-subagent.js".source = ./caveman/caveman-subagent.js;
            }
          ) enabled
        );
      };
  };
}
