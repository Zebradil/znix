{ inputs, ... }:
let
  ponytailOptionsModule =
    { lib, ... }:
    {
      options.znix.claude.ponytail.enable = lib.mkEnableOption "ponytail hooks for claude profiles";
    };
in
{
  flake.modules = {
    nixos.claude-ponytail = ponytailOptionsModule;
    darwin.claude-ponytail = ponytailOptionsModule;

    homeManager.claude-ponytail =
      {
        lib,
        osConfig,
        ...
      }:
      let
        ponytailCfg = osConfig.znix.claude.ponytail or { enable = false; };
        allProfiles = osConfig.znix.claude.profiles or { };
        enabled = lib.filterAttrs (_: p: p.enable && ponytailCfg.enable && p.ponytail) allProfiles;

        ponytailSrc = inputs.self + "/vendor/ponytail";

        mkDirFiles =
          profile: srcDir: destDir:
          lib.mapAttrs' (
            entryName: _type:
            lib.nameValuePair "${profile.configDir}/${destDir}/${entryName}" {
              source = "${srcDir}/${entryName}";
            }
          ) (builtins.readDir srcDir);
      in
      lib.mkIf (ponytailCfg.enable && enabled != { }) {
        home.file = lib.mkMerge (
          lib.mapAttrsToList (
            _: profile:
            (mkDirFiles profile "${ponytailSrc}/hooks" "hooks")
            // (mkDirFiles profile "${ponytailSrc}/skills" "skills")
            // (mkDirFiles profile "${ponytailSrc}/commands" "commands")
          ) enabled
        );
      };
  };
}
