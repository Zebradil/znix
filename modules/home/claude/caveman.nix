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

    homeManager.claude-caveman =
      {
        lib,
        osConfig,
        pkgs,
        ...
      }:
      let
        cavemanCfg = osConfig.znix.claude.caveman or { enable = false; };
        allProfiles = osConfig.znix.claude.profiles or { };
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
          ) enabled
        );
      };
  };
}
