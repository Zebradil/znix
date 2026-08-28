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
  re-transmits over ANT+. Runs as a **native systemd unit**
  (`modules/hosts/toddler/blebridge.nix`), no Docker: the upstream flake's
  `packages.x86_64-linux.blebridge-arm64` is a static-musl aarch64 binary
  (~5.7 MB) cross-built on the deployer, so the Pi never compiles Rust.
  Upstream keeps a container path for other users; it never bound this host
  (see blebridge's `docs/adr/0001-rust-rewrite.md`). App Endpoint pinned to
  hci0 — see DEFER-7 and DEFER-8. Starts at boot and restarts on failure, but
  rate-limited to 5 starts/hour: an occasional crash self-heals, a crash loop
  parks the unit in `failed` rather than resetting USB (and with it Ethernet)
  forever. Recover with `systemctl reset-failed blebridge`.

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
  (reuses existing `inputs.hardware`).
    - **`boot.kernelPackages = pkgs.linuxPackages` must be set explicitly.**
      `raspberry-pi/3` `mkDefault`s the downstream `linux-rpi` kernel, which
      pairs badly with the `sd-image-aarch64` firmware partition: on that
      combination *both* Bluetooth radios are dead. Mainline recovers the USB
      dongle (hci1).
    - **`hardware.deviceTree.name` must name the DTB**
      (`broadcom/bcm2837-rpi-3-b-plus.dtb`). Mainline names this board after
      the SoC (`bcm2837-`); the firmware's `$fdtfile` says `bcm2710-` (the
      downstream name), so `FDTDIR` finds nothing and U-Boot falls back to the
      firmware's own DTB — which boots, but with **no network**, requiring a
      keyboard and display to recover. Naming the DTB emits a concrete `FDT`.
    - **`boot.kernelParams` must be `mkForce`d to drop
      `console=ttyAMA0,115200n8`.** On a 3B+ the PL011 (`ttyAMA0`,
      `3f201000.serial`) *is* the onboard Bluetooth HCI UART; the header
      console is the mini-UART (`ttyS0`, GPIO14/15). `sd-image-aarch64.nix`
      hardcodes that console for QEMU's `-machine virt`, and it kills hci0.
      The option is a plain list and neither the sd-image profile nor
      `nixos-hardware`'s `raspberry-pi/3` uses `mkDefault`, so `mkForce` over
      the whole list is the only way to remove one entry — keep `root=fstab`
      (from nixpkgs' systemd-initrd module) or the box will not boot.
    - Onboard Pi Bluetooth (UART) is **not** optional after all: the App
      Endpoint has to advertise from it (see DEFER-7).
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
- **DEFER-5 — blebridge deployment**: RESOLVED. Deployed as a systemd unit
  from the upstream flake (`modules/hosts/toddler/blebridge.nix`). Verified
  end-to-end: treadmill `C1:5C:7A:44:82:BA` found and connected, ANT channel
  open broadcasting SDM pages as `device_number=12345`. Runs as root — the
  BlueZ D-Bus policy grants `GattCharacteristic1`/`LEAdvertisement1` to
  `user="root"` only, so an unprivileged unit needs a bespoke `org.bluez`
  policy drop-in. ~460 KB resident against a 64 MB cap.
- **DEFER-7 — onboard Bluetooth (hci0)**: RESOLVED. Root cause was
  `console=ttyAMA0,115200n8` on the kernel command line, contributed by
  `sd-image-aarch64.nix` ("for QEMU's `-machine virt`", per its own comment).
  On a 3B+ that PL011 is the Broadcom radio's HCI UART, so the kernel ran a
  console on the chip's serial line: printk went out its RX pin, and
  `pl011_console_write()` clears `CR_CTSEN` for the duration of every write,
  dropping hardware flow control on a link declared `uart-has-rtscts`. The H4
  stream was corrupted and hci0 died on its first command (`0x1001`/`0xfc18`
  tx timeout, `-110`). Raspbian used `console=serial0` → `ttyS0` and never hit
  it. Fix is the `mkForce`d `boot.kernelParams` above; hci0 then comes up as
  Cypress CYW43455, HCI 5.0.
    - Everything that *looked* suspicious was fine and cost time: `BT_ON`
      claimed and high on `raspberrypi-exp-gpio`, PL011 clock 48 MHz,
      `hci_uart_bcm` bound to `serial0-0`, GPIO30–33 in alt3, `BCM4345C5.hcd`
      present. Lowering the console log level (`dmesg -n 1`) does **not**
      exonerate the console — the damage is the `CR_CTSEN` toggle and the
      termios override in `uart_port_startup()`, not the log volume.
    - hci0 runs on the Broadcom factory-default address `43:45:C0:00:1F:AC`.
      Mainline's DTS ships `local-bd-address = [00 00 00 00 00 00]` for the
      VideoCore firmware to overwrite, and the kernel does not consume the
      property here. **Do not bother with a device-tree overlay for it**: one
      was tried, the value never survived to the controller, and it forced a
      118 MB repack of the whole arm64 dtb tree into `/boot` per generation.
    - **Waking hci0 changed blebridge's adapter assignment**, which is what
      actually took the host down. See DEFER-8.
- **DEFER-8 — blebridge must pin the App Endpoint to hci0**: with both radios
  present, blebridge auto-assigned Link→hci0 and App Endpoint→**hci1**. The
  RTL8761BU then threw `hci1: Unexpected advertising set terminated event`
  followed by `usb 1-1.3: reset ... using dwc2`, and since a 3B+ carries its
  Ethernet behind that same USB controller the box dropped off the LAN and
  wedged within seconds — no shutdown records, keyboard needed to recover.
  Fixed by `BLEBRIDGE_APP_ADAPTER = "hci0"` in
  `modules/hosts/toddler/blebridge.nix`; the Link then takes what is left
  (`not_app` in blebridge's `assign_adapters`), so the dongle may renumber
  freely while hci0, the UART chip, never does.
- **DEFER-9 — this box's USB tree is independently flaky**: `dwc2` logs a
  steady stream of `hcint 0x00000402`, devices reset and re-enumerate mid-boot,
  and one gen-11 boot enumerated **no USB at all** (no dongle, no ANT+ stick,
  no Ethernet, `dhcpcd` timed out) with kernel params identical to a
  neighbouring boot that was fine. `rpi_volt`'s `in0_lcrit_alarm` reads 0 and
  no under-voltage is logged, so it is not obviously power. Unexplained;
  suspect a warm-reboot/dwc2 reset issue, unproven. Relevant because it makes
  any single boot a poor experiment — confirm on more than one.
    - The two `0424:2514` hubs are **both internal** and normal for a 3B+ — the
      SoC-side 4-port hub cascades into the LAN7515's own 3-port hub. Nothing
      external is attached; `lsusb -t` reads
      `root_hub -> hub(4p) -> hub(3p) -> {lan78xx, BT500}`, with the Logitech
      receiver and the ANT+ stick on the outer hub. Worth knowing: the **BT500
      shares the inner hub with Ethernet** (`1-1.1.3` vs `1-1.1.1`), so a fault
      on that dongle can take the network down with it.
- **DEFER-6 — AdGuard DHCP**: RESOLVED — DHCP is `enabled: false`. AdGuard is
  DNS-only. No action.
