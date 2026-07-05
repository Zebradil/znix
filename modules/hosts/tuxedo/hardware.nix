{ inputs, ... }:
{
  flake-file.inputs.hardware.url = "github:NixOS/nixos-hardware";

  flake.modules.nixos.tuxedo-hardware =
    { pkgs, ... }:
    {
      imports = [ inputs.hardware.nixosModules.tuxedo-infinitybook-pro14-gen9-amd ];

      hardware = {
        enableRedistributableFirmware = true;

        # - ashell uses org.freedesktop.UPower.PowerProfiles — the power-profiles-daemon D-Bus API
        # - tailord exposes com.tux.Tailor.Performance — its own separate D-Bus API
        #
        # They are incompatible. Switching from power-profiles-daemon to tailord would break ashell's power profile indicator and toggle.
        # tuxedo-rs.enable = true;
        # tuxedo-rs.tailor-gui.enable = true;
        tuxedo-drivers.enable = true;
      };

      boot = {
        kernelPackages = pkgs.linuxKernel.packages.linux_xanmod_latest;
        kernelParams = [
          # Disable USB autosuspend on the Dell WD19TB dock's Realtek hubs.
          # Each physical hub presents two USB IDs — USB 2.0 (5487/5413) and
          # USB 3.0 (0487/0413) — and both halves must be quirked. The :n flag
          # sets USB_QUIRK_NO_AUTOSUSPEND at driver bind time, before userspace
          # (udev, powertop) can interfere.
          #
          # Note: there is also a Bluetooth-correlated dock failure on this
          # platform (Strix Halo + WD19TB over USB4) that *cannot* be fixed
          # with USB quirks — it depends on which physical USB-C port on the
          # laptop the dock is plugged into. Use a port that does not share
          # a USB controller cluster with the internal MediaTek BT (PCIe
          # 00:02.3 / bus 62) — empirically, swapping ports resolves it.
          "usbcore.quirks=0bda:5487:n,0bda:5413:n,0bda:0487:n,0bda:0413:n"

          # Fix external monitor flickering via USB4/Thunderbolt dock (DPIA AUX failures).
          # Disabling scatter-gather display buffers prevents link training resets.
          "amdgpu.sg_display=0"

          # --- AMD Display Flicker Mitigations ---

          # 1. Disable Adaptive Backlight Management (ABM)
          # Fixes split-second brightness changes/pulses when switching between
          # light and dark windows. ABM dynamically dims the backlight while boosting
          # pixel brightness to save battery, but transitions can be jarring.
          # "amdgpu.abmlevel=0"

          # 2. Disable Panel Self Refresh (PSR)
          # Uncomment if you still experience micro-stutters or flickers when the
          # screen wakes up from a static state (e.g., when moving the mouse).
          # "amdgpu.dcdebugmask=0x10"

          # 3. Disable FreeSync / Variable Refresh Rate (VRR) LFC Flicker
          # Uncomment if you use VRR and experience brightness flickers caused by
          # Low Framerate Compensation (LFC) suddenly altering the panel's voltage.
          # "amdgpu.freesync_video=0"
        ];
        initrd = {
          availableKernelModules = [
            "nvme"
            "xhci_pci"
            "thunderbolt"
            "usb_storage"
            "sd_mod"
          ];
          kernelModules = [ "kvm-amd" ];
        };
      };

      services.udev.extraRules = ''
        # Let Vial WebHID access Vial keyboards from browser.
        KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{serial}=="*vial:f64c2b3c*", MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"

        # Keep the WD19TB USB hub functions awake. The kernel quirks set
        # autosuspend delay to 0, but the hubs can still end up with
        # power/control=auto and flap under this platform's USB4 stack.
        ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="0bda", ATTR{idProduct}=="5487", TEST=="power/control", ATTR{power/control}="on"
        ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="0bda", ATTR{idProduct}=="0487", TEST=="power/control", ATTR{power/control}="on"

        # Keep every downstream USB device behind the WD19TB awake too.
        # Matching on ancestor hub IDs avoids pinning the rule to a specific
        # bus number or device path.
        ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", TEST=="power/control", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="5487", ATTR{power/control}="on"
        ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", TEST=="power/control", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="0487", ATTR{power/control}="on"
      '';

      systemd.services.wd19tb-usb-nosuspend = {
        description = "Keep Dell WD19TB USB devices awake";
        wantedBy = [ "multi-user.target" ];
        after = [ "powertop.service" ];
        wants = [ "powertop.service" ];
        serviceConfig.Type = "oneshot";
        script = ''
          is_dock_device() {
            local path="$1"

            while [ -n "$path" ] && [ "$path" != "/" ]; do
              if [ -r "$path/idVendor" ] && [ -r "$path/idProduct" ]; then
                local vendor product
                read -r vendor < "$path/idVendor"
                read -r product < "$path/idProduct"

                case "$vendor:$product" in
                  0bda:5487|0bda:5413|0bda:0487|0bda:0413|413c:b06e|413c:b06f)
                    return 0
                    ;;
                esac
              fi

              path="''${path%/*}"
            done

            return 1
          }

          for dev in /sys/bus/usb/devices/*; do
            [ -w "$dev/power/control" ] || continue

            if is_dock_device "$(readlink -f "$dev")"; then
              printf '%s\n' on > "$dev/power/control" || true
            fi
          done
        '';
      };
    };
}
