_: {
  # Plain GPT: ESP + one ext4 root. UEFI/systemd-boot (see the boot module).
  # Addressed by-id, not /dev/sda: junior also carries iSCSI data LUNs that
  # enumerate as sd*, and by-id pins the wipe to the physical SATA SSD so kernel
  # device reordering can never point disko at a data LUN. (The LUNs aren't even
  # connected in the installer, but this is belt-and-suspenders.)
  flake.modules.nixos.junior-disko = {
    disko.devices.disk.main = {
      device = "/dev/disk/by-id/ata-MTFDDAK256MBF-1AN15ABHA_171716E7B522";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          esp = {
            name = "ESP";
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
