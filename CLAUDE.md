# Claude Code Guidelines for znix

## Architecture

This is a unified Nix configuration using the **dendritic pattern** with flake-parts.

- **Every `.nix` under `modules/`** is a flake-parts module auto-imported via `importTree`
- Modules register into `flake.nixosModules.*`, `flake.darwinModules.*`, or `flake.homeManagerModules.*`
- Hosts in `hosts/` are thin compositions that pull all modules from the appropriate namespace
- Users in `users/` wire system-level config + home-manager

### Shared AI agent assets (`ai/`)

The tool-agnostic agent asset tree lives at the repo root in `ai/`
(`AGENTS.md`, `skills/`, `agents/`, `commands/`, `statusline-command.sh`) — it is
**not** owned by any single tool's module. Both the Claude and opencode home
modules consume it via the `znix.claude.assetsRoot` option, which defaults to
`inputs.self + "/ai"`. `AGENTS.md` is the global instructions file: the Claude
module symlinks it to each profile's `CLAUDE.md`; opencode reads it as `AGENTS.md`.
Vendored skills wire in separately via `znix.claude.extraSkillRoots` (see
`docs/vendored-skills.md`).

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

## Project constraints

### Claude Code profiles & marketplace independence

This repo runs three Claude Code profiles: `personal`, plus the company
`trv-claude` / `trv-claude-key` on host `trv4250` (see
`modules/hosts/trv4250/claude.nix`). The company profiles **cannot use the
official `claude-plugins-official` marketplace** — they are restricted to an
internal marketplace with a limited plugin set.

So any Claude Code feature that depends on a marketplace must be provided in a
**marketplace-independent** way, or it silently won't work on the company
profiles. The LSP wiring follows this: a local `znix-lsp@skills-dir` plugin
(no marketplace) rendered from `znix.lsp.servers`. Prefer uniform,
marketplace-independent mechanisms, and provision all agent tool binaries via
Nix store paths (no tool-side auto-install).

## Agent skills

### Issue tracker

Issues tracked in GitHub Issues (`gh` CLI). External PRs are also a triage
surface. See `docs/agents/issue-tracker.md`.

### Triage labels

Default label vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`,
`ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` + `docs/adr/` at repo root. See
`docs/agents/domain.md`.
