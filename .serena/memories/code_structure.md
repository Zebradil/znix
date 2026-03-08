# Code Structure

```
flake.nix                        # AUTO-GENERATED — do not edit manually
modules/
  flake/                         # perSystem modules: devShell, formatter, overlays
  shared/                        # Registers both nixosModules AND darwinModules
  darwin/                        # darwinModules only
  nixos/                         # nixosModules only (use znix.<name>.enable pattern)
  home/                          # homeManagerModules
  nix/
    flake-parts/
      dendritic-tools.nix        # Bootstrap: systems, flake-parts.modules, flake-file
      lib.nix                    # mkNixos / mkDarwin / mkHomeManager helpers on flake.lib
      factory.nix                # Storage for factory aspect functions
    tools/home-manager/
      home-manager.nix           # HM NixOS+Darwin integration modules
  hosts/
    trv4250/
      flake-parts.nix            # darwinConfigurations.trv4250
      configuration.nix          # Host composition
    tuxedo/
      flake-parts.nix            # nixosConfigurations.tuxedo
      configuration.nix          # Host composition
      hardware.nix / disko.nix
  users/
    glashevich/
      default.nix                # darwin.glashevich module
      _home.nix                  # HM config (underscore = excluded from import-tree)
    zebradil/
      default.nix                # nixos.zebradil module
      home.nix                   # Empty NixOS module (safe for import-tree)
      ssh.pub
secrets/
  hosts/common.yaml              # SOPS-encrypted (age)
  users/zebradil.yaml
assets/bin/                      # Custom scripts
docs/                            # Documentation
```
