{ inputs, ... }:
{
  # kasha is pulled as a flake for its binary: `kasha emit` is the single source
  # of truth for the generation-manifest format, so nothing here vendors a copy
  # that could drift. Pinned via flake.lock (renovate bumps it). The consumer
  # side reads from the box via nix-settings' extra-substituters, not kasha's
  # modules, so its nixosModules are intentionally out of reach.
  flake-file.inputs.kasha = {
    url = "github:Zebradil/kasha";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  perSystem =
    { system, ... }:
    {
      # Resolved by the CI publish job (`nix build .#kasha`) and baked into the
      # local cache-push app. Publishing NARs without emitting a generation
      # manifest leaves them undiscoverable to the box's mirror-down.
      packages.kasha = inputs.kasha.packages.${system}.kasha;
    };
}
