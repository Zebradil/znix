# Standalone home-manager, split from NixOS/Darwin

Status: accepted

Home-manager was wired in **integrated mode** (`home-manager.users.<user>` inside
each NixOS/Darwin system), so `nixos-rebuild switch` re-evaluated the whole system
and ran full system activation even for a one-line user-script change. To get a fast
edit loop, we split home into **standalone** `homeConfigurations."<user>@<host>"`
built via `mkHomeManager`, switched independently with `home-manager switch`. System
configs keep only the user *account*; all user-tool config (claude, lsp, home
persistence) moves to home scope.

## Considered Options

- **Quick-win (writable out-of-store symlinks)** — flip `znix.useWritableLinks` back
  on so edits go live with no rebuild. Rejected: it was deliberately disabled on the
  impermanent Linux host (commit `acced9d`) because a fresh impermanent boot has no
  `~/code` checkout yet, so every out-of-store symlink dangles until the repo is
  cloned. And it is insufficient alone — nix-embedded scripts and tool configs (zsh,
  nixvim) still need a rebuild. Instead, a fast standalone `home-manager switch`
  re-copies store-backed files cheaply, keeping impermanence's fresh-boot guarantee.
- **Dual (keep integrated + add standalone)** — rejected. Its *clean* form still
  requires severing the `osConfig` coupling (~30 modules), so it costs almost as much
  upfront as a full split while carrying a permanent tax: two eval paths green in CI,
  a bridge wired in two places per new coupling, and nixpkgs/overlay divergence risk.
  Its only advantage — an `nixos-rebuild` fallback that also builds home — did not
  justify the ongoing cost.
- **Stub `osConfig` shim** — inject a fake `osConfig` into standalone via
  `extraSpecialArgs`. Rejected: preserves the mis-scoping (a user tool's config living
  in the system namespace) and creates a second source of truth that silently drifts.

## Consequences

- **Two switch commands** per host (`nixos-rebuild`/`darwin-rebuild` for the system,
  `home-manager` for home). No single command deploys both.
- **Fresh-machine bootstrap ordering**: the system switch must run first — it owns
  `/persist` creation, `chown /persist/$HOME`, and `programs.fuse.userAllowOther`
  that home persistence bind-mounts depend on.
- **Divergence is prevented structurally, not by discipline**: each `<user>@<host>`
  home consumes *that host's* nixpkgs input (tuxedo pins `nixpkgs-tuxedo`) and applies
  `self.overlays.default`, so system and home resolve to the same rev + overlays at
  every commit. The only residual skew is temporal (between the two switch commands
  after `nix flake update`) and matters only for the version-coupled
  compositor↔config interface (Hyprland).
- **Impermanence splits**: system persists system dirs; home imports the
  home-manager impermanence module and persists home dirs behind a home-scope
  `znix.impermanence.enable`.
