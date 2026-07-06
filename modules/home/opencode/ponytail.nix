{ inputs, ... }:
{
  flake.modules.homeManager.opencode-ponytail =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      profiles = config.znix.claude.profiles or { };
      personal = profiles.personal or null;
      ponytailOn = (config.znix.claude.ponytail.enable or false) && personal != null && personal.ponytail;
      ponytailSrc = inputs.self + "/vendor/ponytail";
    in
    # The plugin path in opencode.json (./plugins/ponytail/ponytail.mjs) is wired
    # in opencode/default.nix's ocSettings. Here we only place the file. The
    # plugin resolves its dependencies with realpath-relative requires
    # (../../hooks, ../../skills, ../command), and Node resolves the symlink to
    # the vendored store tree, so the whole vendor/ponytail subtree stays intact
    # and reachable — no need to mirror hooks/skills into the opencode dir.
    lib.mkIf ponytailOn {
      home.packages = [ pkgs.nodejs ];

      home.file.".config/opencode/plugins/ponytail/ponytail.mjs".source =
        "${ponytailSrc}/.opencode/plugins/ponytail.mjs";
    };
}
