# znix - Unified Nix Configuration

Unified Nix configuration for macOS (darwin) and NixOS hosts using the **dendritic pattern** (flake-parts).

## Hosts

| Host      | Platform       | User        | Description                           |
|-----------|----------------|-------------|---------------------------------------|
| trv4250   | aarch64-darwin | glashevich  | macOS workstation                     |
| tuxedo    | x86_64-linux   | zebradil    | Tuxedo InfinityBook Pro 14 Gen9 AMD   |

## Architecture

Every `.nix` file under `modules/` is a **flake-parts module** that registers NixOS, darwin, or home-manager modules into flake outputs. Hosts are thin compositions that pull in all registered modules.

```
modules/
  flake/     -> perSystem: devShell, formatter, overlays
  shared/    -> Cross-platform modules (NixOS + darwin)
  darwin/    -> darwin-only system modules
  nixos/     -> NixOS-only system modules (with enable flags)
  home/      -> home-manager modules (loaded for all users)
```

### Optional Features

NixOS-only optional modules use `znix.<feature>.enable`:
- `znix.boot.enable` - systemd-boot
- `znix.disko.enable` - disk management
- `znix.ephemeral-btrfs.enable` - root wipe/restore
- `znix.impermanence.enable` - opt-in persistence
- `znix.laptop.enable` - power/display management
- `znix.wireless.enable` - WiFi + Bluetooth
- `znix.fido.enable` - U2F/YubiKey PAM

## Quick Start

```bash
# Enter dev shell
nix develop

# Check flake
nix flake check

# Build without applying
nix build .#darwinConfigurations.trv4250.system
nix build .#nixosConfigurations.tuxedo.config.system.build.toplevel

# Apply
darwin-rebuild switch --flake .#trv4250    # macOS
nixos-rebuild switch --flake .#tuxedo      # NixOS
```

## Directory Overview

```
flake.nix           Entry point (flake-parts mkFlake)
lib/                importTree helper
modules/            Auto-loaded flake-parts modules
hosts/              Thin host compositions
users/              User definitions + home-manager wiring
secrets/            SOPS-encrypted secrets
assets/bin/         Custom scripts
docs/               Documentation
```
