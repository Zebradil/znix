# toddler — Raspberry Pi 3B+ (LAN appliance)

Headless Raspberry Pi 3B+ joining the NixOS fleet. Replaces an old Raspbian
install. Runs LAN infrastructure services. Divergences from fleet norms are
recorded in [ADR 0001](../adr/0001-toddler-appliance-host.md).

> **Public repo note:** `znix` is public. The AdGuard admin password inlined in
> `adguard.nix` is the bcrypt hash of a *random throwaway* password (unique to
> this LAN-only UI), never a reused credential. Rotate it in the UI at will.

## Roles

- **LAN DNS** — AdGuard Home. Runs today as the official `adguard/adguardhome`
  **Docker container**; config at `/home/suok/confdir/AdGuardHome.yaml`,
  work dir `/home/suok/workdir`. **DNS-only** — DHCP is `enabled: false`
  (router does DHCP; the 67/68 image ports are unused). Migrate container →
  native declarative `services.adguardhome`. Settings to port:
    - upstreams `[/lan/] 192.168.0.1`, `8.8.4.4`, `1.0.0.1`, `9.9.9.9`
      (`load_balance`); bootstrap Quad9; DNSSEC on; optimistic cache 32 MB;
      `use_private_ptr_resolvers: true`.
    - filters: "AdGuard DNS filter" (enabled), "AdAway" (disabled);
      user_rules/whitelist empty.
    - admin UI on port 80, single user `zebradil` (bcrypt hash).
- **apt-cacher-ng** — **DROPPED.** Only 2 consumers, unstable, no attachment.
  Not migrated. 2 Ubuntu machines will hit upstream mirrors directly. Re-add
  later only if bandwidth actually hurts.
- **blebridge** — custom app: reads Bluetooth (BLE) treadmill data,
  re-transmits over ANT+. Runs today as locally-built `blebridge:local`
  Docker container: single static aarch64 binary (`/blebridge`, ~5.7 MB, not
  Go), **host network**, `/dev/bus/usb` passthrough (ANT+ stick), `/run/dbus`
  bind (BlueZ). Image `Created` epoch = 1980 → looks Nix-`dockerTools`-built
  already. Source NOT on the Pi.

## Current hardware (read off the box via SSH)

- Debian 11 bullseye, kernel `6.6.22-v8+`, `aarch64`. 957 MB RAM, ~100 MB swap.
- 32 GB SD: 19 GB used, ~9 GB free.
- USB: **ANT+** `0fcf:1008 Dynastream ANTUSB2 Stick`; **two BT dongles**
  `0b05:190e ASUS USB-BT500` + `0a12:0001 CSR` (adapters hci1/hci2).
- Both AdGuard and blebridge run under Docker (`unless-stopped`).

## Hardware / platform

- RPi 3B+, `aarch64-linux`, 1 GB RAM, boots from SD card. **Fixed** hardware.
- Consequence: never run heavy Nix evaluation/builds on-box (1 GB + SD will
  thrash/OOM).

## Decided

- **Build & deploy**: build on `tuxedo` via binfmt aarch64 emulation, deploy
  with `nixos-rebuild switch --flake .#toddler --target-host toddler
  --build-host tuxedo --use-remote-sudo`. No deploy-rs/colmena. kasha cache
  absorbs rebuild cost.
- **Bootstrap**: flash stock NixOS `aarch64` SD image to a **spare** SD card,
  swap it in, then converge with the deploy flow above. Keep the old Raspbian
  card untouched as instant rollback and as the migration source for existing
  state. No nixos-anywhere (kexec unreliable on RPi 3B+).
- **Filesystem**: plain ext4 root on SD. **No** ephemeral-btrfs, **no**
  impermanence (appliance has little mutable state; btrfs CoW worsens SD wear).
- **Identity**: hostname `toddler`, static IP `192.168.0.20` via **router DHCP
  reservation** (IP truth stays on the router, not baked into config).
- **Networking**: wired `eth0` (MAC `b8:27:eb:87:9a:96`), DHCP, reservation on
  the router. Subnet is `/16` (`192.168.0.0/16`). Do NOT enable the `wireless`
  module — WiFi (`wlan0`) is unused, keeps phase 1 secret-free (no PSK).
- **Secrets**: phase 1 is **sops-free**. Only secret is AdGuard's admin bcrypt
  hash → inlined in `services.adguardhome.settings.users` (LAN-only UI). sops
  arrives later with tailscale (DEFER-3).
- **Domain**: omit `networking.domain` (do not reuse public `zebradil.dev` for
  an internal-only host).
- **User**: lean appliance admin user `suok` — `isNormalUser`, `wheel`,
  `authorizedKeys` from `modules/users/zebradil/ssh.pub`, **no** home-manager,
  **no** password. sudo via `security.pam.sshAgentAuth` (already enabled by the
  shared `openssh` module) → passwordless deploy with forwarded agent, no sops
  password secret needed in phase 1.

- **Boot/firmware**: mainline `aarch64` kernel + extlinux
  (`boot.loader.generic-extlinux-compatible.enable = true`,
  `boot.loader.grub.enable = false`) + `nixos-hardware` `raspberry-pi/3` module
  (reuses existing `inputs.hardware`). Onboard Pi Bluetooth (UART) ignored —
  blebridge uses USB BT dongles.
- **CI**: no `checks` entry for toddler initially (hand-listed in
  `modules/flake/ci.nix`; adding a host does not auto-break CI). Build/verify
  locally on tuxedo via binfmt. Add an `aarch64-linux.toddler-build` check
  later if desired (needs qemu on the runner).

## Module layout (planned)

- `modules/hosts/toddler/flake-parts.nix` — `mkNixos "aarch64-linux" "toddler"`
  + `nixosSystemMap.toddler = "aarch64-linux"`.
- `modules/hosts/toddler/configuration.nix` — `flake.modules.nixos.toddler`:
  imports the lean shared set (`nix-settings`, `openssh`, `locale`,
  `determinate`?), the `suok` user, the host hardware + adguard modules;
  sets hostname, `system.stateVersion`, service toggles. No home-manager,
  no impermanence/ephemeral-btrfs/wireless/desktop.
- `modules/hosts/toddler/hardware.nix` — `nixos-hardware` rpi3 import, extlinux
  loader, `hardware.enableRedistributableFirmware`, `hardware.bluetooth.enable`
  (+ `Experimental`), ANT+ udev rules (`0fcf:1008`/`0fcf:1009`), `usbutils`,
  filesystems by the stock image labels (`NIXOS_SD` + firmware FAT).
- `modules/hosts/toddler/adguard.nix` (host-scoped) — declarative
  `services.adguardhome` with the migrated settings + `systemd-resolved` stub
  disabled. Inlined here rather than a fleet-wide module (single consumer).
- `modules/users/suok/default.nix` — lean `flake.modules.nixos.suok` user.

## Migration & cutover plan (phases)

1. **Prep**: back up old card offline; note it stays as rollback. Copy
   `AdGuardHome.yaml` values into the declarative config (done during build).
2. **Build**: on tuxedo, `nix flake check` + build toddler toplevel via binfmt.
3. **Bootstrap**: flash stock NixOS aarch64 SD image to a SPARE card; boot it
   in the Pi (old card set aside). Confirm SSH + `eth0` DHCP.
4. **Converge**: `nixos-rebuild switch --flake .#toddler --target-host
   suok@192.168.0.20 --build-host tuxedo --use-remote-sudo`.
5. **Verify DNS**: from a client, `dig @192.168.0.20 example.com`; check a
   blocked domain returns `0.0.0.0`/NXDOMAIN; admin UI on `http://192.168.0.20`.
6. **Cutover**: set the router DHCP reservation for MAC
   `b8:27:eb:87:9a:96` → `192.168.0.20`; confirm clients still resolve.
7. **Rollback if needed**: power off, swap the old Raspbian card back in.

## Open items (deferred)

- **DEFER-1 — SD-card wear**: apt cache gone, so remaining writes are small —
  AdGuard query log + statistics (currently 90d, file-backed) and journald.
  Mitigate with shorter retention and/or journald `Storage=volatile` +
  tmpfs/log2ram for the AdGuard work dir. Low urgency.
- **DEFER-2 — external USB disk**: MOOT (was for the apt cache, now dropped).
- **DEFER-3 — tailscale**: enable the shared `tailscale` module for
  deploy/SSH reach. Deferred, not required for the LAN DNS role.
- **DEFER-4 — apt-proxy identity**: confirm what the current systemd service
  actually is (apt-cacher-ng? custom?) before modelling it in Nix.
- **DEFER-5 — blebridge deployment**: OUT of initial scope. Source is a WIP
  Rust rewrite at `~/code/github.com/zebradil/blebridge`; user packages + wires
  the systemd service later. Initial migration only guarantees the **substrate**:
    - `hardware.bluetooth.enable = true` with latest BlueZ (BLE central;
      likely `settings.General.Experimental = true`).
    - udev rules granting raw USB access to ANT+ sticks (`0fcf:1008`,
      `0fcf:1009`) for the blebridge service user (libusb userspace, no kernel
      driver needed).
    - `usbutils` for debugging.
- **DEFER-6 — AdGuard DHCP**: RESOLVED — DHCP is `enabled: false`. AdGuard is
  DNS-only. No action.
