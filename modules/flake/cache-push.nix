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
            runtimeInputs = with pkgs; [
              sops
              git
              coreutils
              gnugrep
              gnused
              findutils
            ];
            # Emit kasha generation manifests for locally-pushed closures, so
            # they are discoverable by the box's mirror-down. The emitter is
            # pinned via the kasha flake input (no drift). Exports precede the
            # readFile body; the body's shebang line is then just a comment.
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
