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
    # Home scope needs the option declared too, so home profiles can set
    # znix.claude.ponytail.enable directly (no osConfig). Swept like claude-options.
    homeManager.claude-ponytail-options = ponytailOptionsModule;

    homeManager.claude-ponytail =
      {
        lib,
        config,
        ...
      }:
      let
        ponytailCfg = config.znix.claude.ponytail or { enable = false; };
        allProfiles = config.znix.claude.profiles or { };
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
