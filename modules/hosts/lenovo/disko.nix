_: {
  # ESP + LUKS with btrfs inside. The passphrase is read from
  # /tmp/disk.key at format time only; nixos-anywhere puts it there via
  # --disk-encryption-keys (see docs/hosts/lenovo.md).
  flake.modules.nixos.lenovo-disko = {
    disko.devices.disk.main = {
      device = "/dev/nvme0n1";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          esp = {
            name = "ESP";
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "lenovo";
              passwordFile = "/tmp/disk.key";
              settings.allowDiscards = true;
              content = {
                type = "btrfs";
                extraArgs = [ "-Llenovo" ];
                subvolumes =
                  let
                    opts = [
                      "compress=zstd"
                      "noatime"
                    ];
                  in
                  {
                    "/root" = {
                      mountpoint = "/";
                      mountOptions = opts;
                    };
                    "/home" = {
                      mountpoint = "/home";
                      mountOptions = opts;
                    };
                    "/nix" = {
                      mountpoint = "/nix";
                      mountOptions = opts;
                    };
                  };
              };
            };
          };
        };
      };
    };
  };
}
