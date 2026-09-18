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

        ponytailRoot = inputs.self + "/vendor/ponytail";
        # Scoped store copy: linking straight into inputs.self would pin the
        # whole flake source, so any tracked file change rebuilds the profile.
        # It backs the symlink targets only — the readDir below goes through
        # ponytailRoot (context: the flake source, always valid), because
        # `nix flake check --no-build` opens the store read-only and the copy
        # is then only dry-run computed, so reading it fails with "path '...'
        # is not valid".
        ponytailStore = builtins.path {
          path = ponytailRoot;
          name = "znix-vendor-ponytail";
        };

        mkDirFiles =
          profile: sub:
          lib.mapAttrs' (
            entryName: _type:
            lib.nameValuePair "${profile.configDir}/${sub}/${entryName}" {
              source = "${ponytailStore}/${sub}/${entryName}";
            }
          ) (builtins.readDir (ponytailRoot + "/${sub}"));
      in
      lib.mkIf (ponytailCfg.enable && enabled != { }) {
        home.file = lib.mkMerge (
          lib.mapAttrsToList (
            _: profile:
            (mkDirFiles profile "hooks") // (mkDirFiles profile "skills") // (mkDirFiles profile "commands")
          ) enabled
        );
      };
  };
}
