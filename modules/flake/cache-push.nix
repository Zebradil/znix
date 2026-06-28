_: {
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
            ];
            text = builtins.readFile ./scripts/cache-push-local.sh;
          }
        }/bin/cache-push";
      };
    };
}
