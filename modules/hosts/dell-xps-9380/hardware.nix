{ inputs, ... }:
{
  flake.modules.nixos.dell-xps-9380-hardware = _: {
    imports = [ inputs.hardware.nixosModules.dell-xps-13-9380 ];

    # The hardware module's `common/pc/laptop` enables TLP by default
    # (mkDefault (!power-profiles-daemon.enable)). TLP autosuspends USB, which
    # would kill the USB-C Ethernet dongle. Opt out; use thermald (already on
    # from the hardware module) + schedutil instead.
    services.tlp.enable = false;
    powerManagement.cpuFreqGovernor = "schedutil";

    hardware.enableRedistributableFirmware = true;

    boot.initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
    ];
  };
}
