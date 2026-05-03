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
        # Disable USB autosuspend for Dell WD19TB dock Realtek hubs.
        # Without this, the kernel suspends the hubs during enumeration,
        # causing immediate disconnect (err -5, err -32) and breaking
        # all USB-A ports on the dock. The :n flag sets
        # USB_QUIRK_NO_AUTOSUSPEND at driver bind time, before any
        # userspace (udev, powertop) can interfere.
        "usbcore.quirks=0bda:5487:n,0bda:5413:n"
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
