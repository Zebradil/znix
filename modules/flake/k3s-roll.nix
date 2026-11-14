{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      # `nix run .#k3s-roll -- [NODE...] [-- COLMENA_APPLY_ARGS...]` from the
      # repo root (colmena reads ./flake.nix). See
      # docs/adr/0008-k3s-restart-only-when-drained.md.
      apps.k3s-roll = {
        type = "app";
        program = "${
          pkgs.writeShellApplication {
            name = "k3s-roll";
            runtimeInputs = [
              pkgs.kubectl
              inputs.colmena.packages.${system}.colmena
            ];
            text = builtins.readFile ./scripts/k3s-roll.sh;
          }
        }/bin/k3s-roll";
      };
    };
}
