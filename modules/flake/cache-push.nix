{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
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
              # For kasha root-manifest emission (emit-root-manifest.sh).
              awscli2
              jq
            ];
            # Emit kasha root manifests for locally-pushed generations, so they
            # are discoverable by the box's mirror-down. The emit script is
            # pinned via the kasha source input (no drift). Exports precede the
            # readFile body; the body's shebang line is then just a comment.
            text = ''
              export KASHA_FLAKE=znix
              export KASHA_EMIT_SCRIPT=${inputs.kasha}/scripts/emit-root-manifest.sh
            ''
            + builtins.readFile ./scripts/cache-push-local.sh;
          }
        }/bin/cache-push";
      };
    };
}
