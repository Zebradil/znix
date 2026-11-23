_: {
  # Ex-gaming desktop: Ryzen 7 2700X on a Gigabyte X470 AORUS ULTRA GAMING,
  # Crucial MX500 SATA SSD (root), WD40EZRZ 4 TB SATA HDD (bulk data),
  # Intel I211 NIC, GTX 1070 Ti for Jellyfin's NVENC.
  flake.modules.nixos.daddy-hardware =
    { config, lib, ... }:
    {
      boot.initrd.availableKernelModules = [
        "ahci"
        "xhci_pci"
        "sd_mod"
      ];
      boot.kernelModules = [ "kvm-amd" ];

      hardware.enableRedistributableFirmware = true;
      hardware.cpu.amd.updateMicrocode = true;

      # Pascal is not supported by the open kernel modules; legacy_580 is the
      # last proprietary branch that drives it.
      hardware.nvidia = {
        package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
        open = false;
        nvidiaSettings = false;
        # Headless: with no display client the driver would tear the GPU state
        # down after every transcode; the daemon keeps it initialised.
        nvidiaPersistenced = true;
      };
      hardware.graphics.enable = true;
      # Selects the driver for hardware.nvidia; no X server runs.
      services.xserver.videoDrivers = [ "nvidia" ];

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
}
