# toddler is an appliance host that opts out of fleet conventions

`toddler` (a Raspberry Pi 3B+, `aarch64`, 1 GB RAM, SD-booted) joins the fleet
as a headless LAN appliance running AdGuard Home. Unlike the workstation hosts,
it deliberately **omits impermanence / ephemeral-btrfs** (plain ext4: an
appliance has little mutable state, and btrfs CoW worsens SD-card wear) and
**does not use the shared `zebradil` user** (that module imports the full
home-manager desktop closure, which is wrong to drag onto a 1 GB SD Pi).
Instead it uses a lean `suok` user with no home-manager and no password
(sudo via ssh-agent), and phase 1 is intentionally sops-free.

## Consequences

- A future reader should not "fix" toddler to match the other hosts — the
  divergences are intentional, driven by the fixed weak hardware.
- toddler is never built on-box: closures are built on `tuxedo` via binfmt and
  deployed with `nixos-rebuild --target-host … --build-host tuxedo`.
- Secrets (sops) and Tailscale are deferred until actually needed; see
  `docs/hosts/toddler.md` for the running decision log and open items.
