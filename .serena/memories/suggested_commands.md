# Suggested Commands

## Development
```bash
nix develop                          # Enter dev shell
nix flake check                      # Validate the flake
nix fmt                              # Format with nixfmt-rfc-style (formatter = nixfmt)
nix run .#write-flake                # Regenerate flake.nix (DO NOT manually edit flake.nix)
```

## Build (without applying)
```bash
nix build .#darwinConfigurations.trv4250.system
nix build .#nixosConfigurations.tuxedo.config.system.build.toplevel
```

## Apply
```bash
darwin-rebuild switch --flake .#trv4250    # Apply on macOS (trv4250)
nixos-rebuild switch --flake .#tuxedo      # Apply on NixOS (tuxedo)
```

## Secrets (sops-nix)
```bash
sops secrets/hosts/common.yaml            # Edit encrypted secrets
sops secrets/users/zebradil.yaml
```

## Git / System Utilities (Darwin)
```bash
git status / git log / git diff
ls / find / grep / cat / head / tail
```
