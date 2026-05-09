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

      boot.kernelPackages = pkgs.linuxKernel.packages.linux_xanmod_latest;
      boot.kernelParams = [
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
      ];
      boot.initrd = {
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
}
