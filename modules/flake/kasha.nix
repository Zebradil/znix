{ inputs, ... }:
{
  # kasha is pulled source-only (flake = false): we consume a single script from
  # its tree, not its flake outputs. This pins it via flake.lock (renovate bumps
  # it) so the vendored-copy drift problem never arises. The consumer side reads
  # from the box via nix-settings' extra-substituters, not kasha's modules, so
  # its nixosModules are intentionally out of reach.
  flake-file.inputs.kasha = {
    url = "github:Zebradil/kasha";
    flake = false;
  };

  # Root-manifest emitter, resolved to a store path by callers that publish to
  # the cache (CI build job via `nix eval --raw .#lib.kashaEmitScript`, and the
  # local cache-push app which bakes it in). Publishing NARs without emitting a
  # root manifest leaves them undiscoverable to the box's mirror-down.
  flake.lib.kashaEmitScript = inputs.kasha + "/scripts/emit-root-manifest.sh";
}
