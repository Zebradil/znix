{ ... }:
{
  perSystem =
    { pkgs, config, ... }:
    {
      # `nix run .#cache-push -- <attr>...` — decrypt the cache secrets from
      # secrets/cache.yaml and sign + push the resolved store paths to the S3
      # binary cache, reusing the same core script CI runs. See docs/cache.md.
      apps.cache-push = {
        type = "app";
        program = "${
          pkgs.writeShellApplication {
            name = "cache-push";
            # Just this wrapper's own needs (sops, git, mktemp/rm); the core
            # script brings its own toolchain.
            runtimeInputs = [
              pkgs.sops
              pkgs.git
              pkgs.coreutils
              config.packages.cache-push
            ];
            # Emit kasha generation manifests for locally-pushed closures, so
            # they are discoverable by the box's mirror-down. Both the emitter
            # and the push core come from the kasha flake input (no drift).
            # Exports precede the readFile body; the body's shebang line is
            # then just a comment.
            text = ''
              export KASHA_FLAKE=znix
              export KASHA_BIN=${config.packages.kasha}/bin/kasha
            ''
            + builtins.readFile ./scripts/cache-push-local.sh;
          }
        }/bin/cache-push";
      };
    };
}
