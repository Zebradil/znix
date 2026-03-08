# znix-new Project Overview

## Purpose
Unified Nix configuration for macOS (darwin) and NixOS hosts using the **dendritic pattern** with flake-parts.

## Tech Stack
- **Nix** (primary language, nixpkgs-unstable)
- **flake-parts** - modular flake structure
- **flake-file** - auto-generates flake.nix from module options
- **import-tree** - auto-imports all .nix files under modules/
- **home-manager** - user environment management
- **nix-darwin** - macOS system configuration
- **sops-nix** - secrets management
- **disko** - declarative disk partitioning
- **impermanence** - opt-in persistent state

## Hosts
| Host    | Platform       | User       | Description                          |
|---------|----------------|------------|--------------------------------------|
| trv4250 | aarch64-darwin | glashevich | macOS workstation (Determinate Nix)  |
| tuxedo  | x86_64-linux   | zebradil   | Tuxedo InfinityBook Pro 14 Gen9 AMD  |

## Key Architecture Points
- `flake.nix` is AUTO-GENERATED via `nix run .#write-flake` — DO NOT manually edit it
- Every `.nix` under `modules/` is a flake-parts module auto-imported via `import-tree`
- Prefix non-flake-parts .nix files with `_` to exclude from import-tree (e.g. `_home.nix`)
- Modules register into `flake.modules.nixos.*`, `flake.modules.darwin.*`, `flake.modules.homeManager.*`
