# Task Completion Checklist

After completing any editing task:

1. **Format**: `nix fmt` — format all Nix files with nixfmt-rfc-style
2. **Validate**: `nix flake check` — ensure the flake evaluates without errors
3. **If flake inputs changed**: `nix run .#write-flake` — regenerate `flake.nix`
4. **Build target** (optional, if applicable):
   - macOS: `nix build .#darwinConfigurations.trv4250.system`
   - NixOS: `nix build .#nixosConfigurations.tuxedo.config.system.build.toplevel`
