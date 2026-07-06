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
- **Impermanence is system-owned, not split** (revised — the original plan to
  import a home-manager impermanence module in standalone does not work).
  Current `impermanence` dropped standalone-home-manager support: its
  `home-manager.nix` is a validation-only shim, and *all* bind-mounting lives in
  its NixOS module. So the **system switch owns every persistence bind-mount**
  (system dirs *and* home dirs); standalone `home-manager switch` only re-links
  store-backed files and performs no mounts. This does not affect the
  fast-iteration goal: user-tool config is store-backed symlinks that
  `home-manager switch` re-links without any bind-mount.
- **The system still owns home persistence without evaluating home for
  activation.** `environment.persistence."/persist".users.<name>.directories` is
  sourced from `self.homeConfigurations."<user>@<host>".config.home.persistence`
  — the standalone home config's aggregated persist set (each tool's home module
  still declares its own dirs; the home-scope impermanence stub is a minimal
  mergeable schema so those writes concatenate). Reading that string list forces
  home *option* evaluation only, never a home *build*, so `nixos-rebuild` builds
  no home closure and a `home-manager switch` needs no `nixos-rebuild`. The
  system switch is required only when the *set* of persisted directories changes.
  This keeps a single source of truth (the tool modules) while the mounts are
  declared and executed entirely on the NixOS side.
