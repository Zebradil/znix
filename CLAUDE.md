# Claude Code Guidelines for znix

## Architecture

This is a unified Nix configuration using the **dendritic pattern** with flake-parts.

- **Every `.nix` under `modules/`** is a flake-parts module auto-imported via `importTree`
- Modules register into `flake.nixosModules.*`, `flake.darwinModules.*`, or `flake.homeManagerModules.*`
- Hosts in `hosts/` are thin compositions that pull all modules from the appropriate namespace
- Users in `users/` wire system-level config + home-manager

## Key Patterns

### Adding a module

Create a `.nix` file under the appropriate `modules/` subdirectory. It must be a flake-parts module:

```nix
{ ... }: {
  flake.nixosModules.my-feature = { config, lib, ... }: { /* NixOS config */ };
}
```

### Optional NixOS features

Use `znix.<name>.enable` with `lib.mkEnableOption` + `lib.mkIf`.

### Module namespaces

- `modules/shared/` -> registers both `nixosModules` AND `darwinModules`
- `modules/darwin/` -> registers `darwinModules` only
- `modules/nixos/` -> registers `nixosModules` only
- `modules/home/` -> registers `homeManagerModules`
- `modules/flake/` -> `perSystem` (devShell, formatter, overlays)

## Commands

```bash
nix flake check                    # Validate
nix develop                        # Dev shell
nix fmt                            # Format with nixfmt-tree
darwin-rebuild switch --flake .    # Apply on macOS
nixos-rebuild switch --flake .     # Apply on NixOS
```

## Secrets

Managed with sops-nix. See `docs/secrets.md`. Never commit unencrypted secrets.

## Package pins

Temporarily override broken packages via the `pins` map in `modules/flake/overlays.nix`. See `docs/package-pins.md`.
