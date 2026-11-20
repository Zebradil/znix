# lenovo — ThinkPad T480s (family laptop)

Alis's laptop for video calls and browsing: GNOME, Chrome, Firefox, Zoom, Telegram, LibreOffice, the home Brother
printer. Administered over SSH as `suok` and deployed with colmena (tag `desktop`). Replaced an Arch install.

## Hardware

i7-8550U, 16 GB RAM, 512 GB Samsung NVMe, Intel 8265 WiFi, UEFI. The fingerprint reader (06cb:009a) and the LTE modem
are not configured. The battery holds about half its design capacity.

## Layout and state

- Disk: ESP + LUKS + btrfs (`/root`, `/home`, `/nix`), zram swap. No impermanence: the root is persistent.
- Host SSH key is pre-generated: private half in `secrets/hosts/lenovo/ssh_host_ed25519.key` (encrypted to the
  `zebradil` key only), public half beside it. Its age key is the `lenovo` recipient in `.sops.yaml`.
- `secrets/hosts/lenovo.yaml` holds `alis-password`, the hash carried over from the Arch install.
- WiFi: `DUST`, `DUSTY`, `DUSTIER`, all from the `wireless` key in `secrets/hosts/common.yaml`.

## Install

Back up everything worth keeping first: the install wipes the disk. Pick a time when the laptop is not needed.

1. Give the installer root on the Arch system: put the `zebradil` public key into `/root/.ssh/authorized_keys` and
   allow root key login in sshd, or give `zebradil` passwordless sudo.
2. Stage the host key and the LUKS passphrase (outside the extra-files tree):

   ```bash
   tmp=$(mktemp -d)
   install -d -m 755 "$tmp/root/etc/ssh"
   sops -d secrets/hosts/lenovo/ssh_host_ed25519.key > "$tmp/root/etc/ssh/ssh_host_ed25519_key"
   chmod 600 "$tmp/root/etc/ssh/ssh_host_ed25519_key"
   cp secrets/hosts/lenovo/ssh_host_ed25519.key.pub "$tmp/root/etc/ssh/ssh_host_ed25519_key.pub"
   read -rs 'pass?LUKS passphrase: ' && printf %s "$pass" > "$tmp/disk.key" && unset pass
   ```

3. Install. `--build-on remote` builds in the kexec environment on the laptop itself, so the closure is not built on
   macOS. Target the IP, not `lenovo.lan`: the kexec installer takes a new DHCP lease under the hostname
   `nixos-installer`, so the router's name for the laptop disappears mid-run.

   ```bash
   nix run github:nix-community/nixos-anywhere -- \
     --flake .#lenovo --build-on remote \
     --extra-files "$tmp/root" \
     --disk-encryption-keys /tmp/disk.key "$tmp/disk.key" \
     --target-host root@<ip>
   rm -rf "$tmp"
   ```

   The installer's own address can differ from the one used for kexec; find it in the router's lease list. If a run
   dies after kexec, the disk is still untouched: rerun against the installer's address with
   `--phases disko,install,reboot`.

4. After the first boot: `ssh suok@lenovo.lan sudo tailscale up`, restore her files into `/home/alis` (owned by
   `alis`), then let her sign in to Chrome, Telegram and Zoom.

Later changes: `colmena apply --on lenovo`.

## Printer

Brother DCP-L2530DW at `socket://192.168.1.35:9100`, declared with the `brlaser` DCP-L2537DW PPD; brlaser has no entry
for the L2530DW itself. The address comes from the router's DHCP pool, so pin it there. Avahi is on, so GNOME also
offers the printer driverlessly if it advertises AirPrint.
