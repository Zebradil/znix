{ inputs, ... }:
{
  flake-file.inputs.hardware.url = "github:NixOS/nixos-hardware";

  flake.modules.nixos.tuxedo-hardware =
    { pkgs, ... }:
    {
      imports = [ inputs.hardware.nixosModules.tuxedo-infinitybook-pro14-gen9-amd ];

      hardware = {
        enableRedistributableFirmware = true;
        tuxedo-rs.enable = true;
        tuxedo-rs.tailor-gui.enable = true;
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
