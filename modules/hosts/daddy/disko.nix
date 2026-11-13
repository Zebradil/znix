_: {
  # Plain GPT: ESP + one ext4 root on the SSD only. Addressed by-id so disko can
  # never touch the HDD, which holds the only copy of bulk data and is mounted
  # separately (see configuration.nix), never formatted.
  flake.modules.nixos.daddy-disko = {
    disko.devices.disk.main = {
      device = "/dev/disk/by-id/ata-CT500MX500SSD1_1829E14A1F5F";
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
