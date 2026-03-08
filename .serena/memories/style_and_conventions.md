# Style and Conventions

## Nix Code Style
- Formatter: `nixfmt-rfc-style` (invoked via `nix fmt`)
- Note: `nixfmt-rfc-style` was renamed to `nixfmt` in current nixpkgs

## Module Pattern
All `.nix` files under `modules/` must be flake-parts modules:
```nix
{ ... }: {
  flake.nixosModules.my-feature = { config, lib, ... }: { /* NixOS config */ };
}
```

## Optional NixOS Features
Use `znix.<name>.enable` with `lib.mkEnableOption` + `lib.mkIf`:
```nix
options.znix.myfeature.enable = lib.mkEnableOption "my feature";
config = lib.mkIf config.znix.myfeature.enable { ... };
```

## Input Declaration
Each module declares its own inputs via `flake-file.inputs` (not in flake.nix directly).

## Gotchas / Known Issues
- `import-tree` picks up ALL `.nix` files — prefix non-flake-parts with `_` (e.g. `_home.nix`)
- NixOS module `imports` CANNOT be inside `config = lib.mkIf ...` — must be at top level
- Darwin with `nix.enable = false` (Determinate installer): wrap `nix.gc`/`nix.settings` in `lib.mkIf config.nix.enable`
- `programs.light` removed from nixpkgs — use `brightnessctl` instead
- `services.logind.lidSwitch` renamed to `services.logind.settings.Login.Handle*`
- Platform-specific HM packages (e.g. iterm2) go in user's `_home.nix`, NOT generic homeManager modules
- User HM imports: `builtins.attrValues self.modules.homeManager ++ [ ./_home.nix ]`
- sops path from `modules/users/zebradil/default.nix`: `../../../secrets/users/zebradil.yaml`
