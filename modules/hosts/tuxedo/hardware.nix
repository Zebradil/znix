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
