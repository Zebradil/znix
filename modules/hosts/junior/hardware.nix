_: {
  # Intel i5-6500 (Skylake) mini-PC, single SATA AHCI SSD, onboard e1000e NIC.
  flake.modules.nixos.junior-hardware =
    { lib, ... }:
    {
      # AHCI SATA for the root SSD; xhci for USB. iSCSI (the synology-csi data
      # LUNs) is brought up at runtime by openiscsi, not needed in initrd since
      # root is on the local SATA disk.
      boot.initrd.availableKernelModules = [
        "ahci"
        "xhci_pci"
        "sd_mod"
      ];
      boot.kernelModules = [ "kvm-intel" ];

      hardware.enableRedistributableFirmware = true;
      hardware.cpu.intel.updateMicrocode = true;

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
}
