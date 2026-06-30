{ ... }:
{
  # Composes the profile statusline: the znix base line plus one badge per
  # active addon (caveman, ponytail). Both addons ship a `<addon>-statusline.sh`
  # that prints a coloured badge from a flag file; running them in sequence lets
  # the badges stack. Lives in its own module so no single addon owns the
  # statusline file — default.nix symlinks the plain base, this mkForces the
  # composed script whenever at least one badge is active.
  flake.modules.homeManager.claude-statusline =
    {
      lib,
      osConfig,
      pkgs,
      config,
      ...
    }:
    let
      claudeCfg = osConfig.znix.claude or { };
      profiles = claudeCfg.profiles or { };
      enabled = lib.filterAttrs (_: p: p.enable) profiles;
      znixStatusline = "${claudeCfg.assetsRoot}/statusline-command.sh";

      cavemanOn = p: (claudeCfg.caveman.enable or false) && p.caveman;
      ponytailOn = p: (claudeCfg.ponytail.enable or false) && p.ponytail;

      badgeScripts =
        profile:
        lib.optional (cavemanOn profile) "caveman-statusline.sh"
        ++ lib.optional (ponytailOn profile) "ponytail-statusline.sh";

      mkComposed =
        profile: scripts:
        pkgs.writeShellScript "claude-${profile.command}-statusline" ''
          set -uo pipefail
          input=$(cat)
          out=$(printf '%s' "$input" | bash ${znixStatusline})
          ${lib.concatMapStringsSep "\n" (script: ''
            badge=$(printf '%s' "$input" | bash "$HOME/${profile.configDir}/hooks/${script}" || true)
            if [ -n "$badge" ]; then
              out="$out $badge"
            fi
          '') scripts}
          printf '%s' "$out"
        '';
    in
    {
      home.file = lib.mkMerge (
        lib.mapAttrsToList (
          _: profile:
          let
            scripts = badgeScripts profile;
          in
          lib.optionalAttrs (scripts != [ ]) {
            "${profile.configDir}/statusline-command.sh".source = lib.mkForce (mkComposed profile scripts);
          }
        ) enabled
      );
    };
}
