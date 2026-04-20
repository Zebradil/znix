# Package Pins

## When to use

When a package in `nixpkgs-unstable` is temporarily broken but a fix already exists at a known nixpkgs commit. Rather than waiting for unstable to catch up, pin the specific package to the fixed ref.

## Adding a pin

Edit the `pins` attr at the top of `modules/flake/overlays.nix`:

```nix
pins = {
  # Shorthand — pin applies to every system:
  foo = "github:NixOS/nixpkgs/<rev>";

  # Long form — restrict to specific systems:
  nushell = {
    ref = "github:NixOS/nixpkgs/<rev>";
    systems = [ "aarch64-darwin" ];
  };
};
```

Use a specific commit SHA (40 hex chars) rather than a branch so the lock is reproducible. Find the right SHA by browsing the nixpkgs commit history for the package, e.g.:

```
https://github.com/NixOS/nixpkgs/commits/master/pkgs/by-name/nu/nushell/package.nix
```

## Regenerate and lock

New `.nix` files must be staged before Nix evaluates them (not needed for edits to existing files):

```bash
nix run .#write-flake   # regenerates flake.nix with the new input
nix flake lock          # pulls in the pinned nixpkgs
```

## Verify

```bash
nix flake check --no-build
nix build .#darwinConfigurations.<host>.pkgs.<pkgname> --dry-run
nix build .#darwinConfigurations.<host>.pkgs.<pkgname>
```

To confirm a per-system pin is NOT applied on other systems:

```bash
# These two drvPaths should match (pin not applied):
nix eval .#nixosConfigurations.<host>.pkgs.<pkgname>.drvPath
nix eval .#inputs.nixpkgs.legacyPackages.x86_64-linux.<pkgname>.drvPath
```

## Removing a pin

Once the fix reaches `nixpkgs-unstable`, delete the entry from `pins` in `modules/flake/overlays.nix` and update the lock:

```bash
nix run .#write-flake
nix flake lock
```

If all pins are removed, the `pinsOverlay` becomes a no-op and nothing else needs to change.

## Limitations

- Each pin instantiates a separate nixpkgs set; Nix deduplicates store paths so the overhead is minor for temporary use.
- If the same package needs different refs on different systems, declare two pins under distinct names (rare).
