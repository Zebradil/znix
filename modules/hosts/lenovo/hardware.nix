{ inputs, ... }:
{
  flake.modules.nixos.lenovo-hardware = _: {
    # Also enables throttled, which lifts the T480s's firmware power limits.
    imports = [ inputs.hardware.nixosModules.lenovo-thinkpad-t480s ];

    hardware.enableRedistributableFirmware = true;

    boot = {
      initrd.availableKernelModules = [
        "nvme"
        "xhci_pci"
        "usb_storage"
        "sd_mod"
        "rtsx_pci_sdmmc"
      ];
      kernelModules = [ "kvm-intel" ];
    };
  };
}
