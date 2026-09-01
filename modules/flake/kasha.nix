{ inputs, ... }:
{
  # kasha is pulled as a flake for the cache-producer tooling it owns: `kasha
  # emit` (generation-manifest format) and kasha-cache-push (resolve -> sign ->
  # push).
  # Nothing here vendors a copy that could drift from the box that consumes it.
  # Pinned via flake.lock (renovate bumps it). The consumer side reads from the
  # box via nix-settings' extra-substituters, not kasha's modules, so its
  # nixosModules are intentionally out of reach.
  flake-file.inputs.kasha = {
    url = "github:Zebradil/kasha";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  perSystem =
    { system, ... }:
    {
      # The generation-manifest emitter. CI builds its own copy from kasha's
      # emit-manifest action; this attr keeps `kasha emit` reachable locally
      # from the same pin that drives cache-push below.
      packages.kasha = inputs.kasha.packages.${system}.kasha;

      # The resolve -> sign -> push core, from the same pinned input as the
      # emitter it drives. Kept under kasha's own attr name because
      # `apps.cache-push` below is a different thing (the sops wrapper).
      packages.kasha-cache-push = inputs.kasha.packages.${system}.kasha-cache-push;
    };
}
