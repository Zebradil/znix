_: {
  # Ex-gaming desktop: Ryzen 7 2700X on a Gigabyte X470 AORUS ULTRA GAMING,
  # Crucial MX500 SATA SSD (root), WD40EZRZ 4 TB SATA HDD (bulk data),
  # Intel I211 NIC, GTX 1070 Ti left on nouveau until something needs NVENC.
  flake.modules.nixos.daddy-hardware =
    { lib, ... }:
    {
      boot.initrd.availableKernelModules = [
        "ahci"
        "xhci_pci"
        "sd_mod"
      ];
      boot.kernelModules = [ "kvm-amd" ];

      hardware.enableRedistributableFirmware = true;
      hardware.cpu.amd.updateMicrocode = true;

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
}
