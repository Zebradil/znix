{ ... }:
{
  flake.modules.nixos.ephemeral-btrfs =
    { config, lib, ... }:
    {
      options.znix.ephemeral-btrfs.enable = lib.mkEnableOption "ephemeral btrfs root";

      config = lib.mkIf config.znix.ephemeral-btrfs.enable (
        let
          hostname = config.networking.hostName;
          root = config.fileSystems."/";
          wipeScript = ''
            mkdir /tmp -p
            MNTPOINT=$(mktemp -d)
            (
              mount -t btrfs -o subvol=/ ${root.device} "$MNTPOINT"
              trap 'umount "$MNTPOINT"' EXIT

              echo "Creating needed directories"
              mkdir -p "$MNTPOINT"/persist/var/{log,lib/{nixos,systemd}}
              if [ -e "$MNTPOINT/dont-wipe" ]; then
                echo "Skipping wipe"
              else
                echo "Cleaning root subvolume"
                btrfs subvolume delete -R "$MNTPOINT/root"
                echo "Restoring blank subvolume"
                btrfs subvolume snapshot "$MNTPOINT/root-blank" "$MNTPOINT/root"
              fi
            )
          '';
          toSystemdDevice =
            device:
            lib.concatStringsSep "-" (
              lib.tail (map (lib.replaceString "-" "\\x2d") (lib.splitString "/" device))
            )
            + ".device";
          phase1Systemd = config.boot.initrd.systemd.enable;
        in
        {
          boot.initrd = {
            supportedFilesystems = [ "btrfs" ];
            postDeviceCommands = lib.mkIf (!phase1Systemd) (lib.mkBefore wipeScript);
            systemd.services.restore-root = lib.mkIf phase1Systemd {
              description = "Rollback btrfs rootfs";
              wantedBy = [ "initrd.target" ];
              requires = [ (toSystemdDevice root.device) ];
              after = [ (toSystemdDevice root.device) ];
              before = [ "sysroot.mount" ];
              unitConfig.DefaultDependencies = "no";
              serviceConfig.Type = "oneshot";
              script = wipeScript;
            };
          };

          fileSystems = {
            "/" = lib.mkDefault {
              device = "/dev/disk/by-label/${hostname}";
              fsType = "btrfs";
              options = [
                "subvol=root"
                "compress=zstd"
              ];
            };
            "/nix" = lib.mkDefault {
              device = "/dev/disk/by-label/${hostname}";
              fsType = "btrfs";
              options = [
                "subvol=nix"
                "noatime"
                "compress=zstd"
              ];
            };
            "/persist" = lib.mkDefault {
              device = "/dev/disk/by-label/${hostname}";
              fsType = "btrfs";
              options = [
                "subvol=persist"
                "compress=zstd"
              ];
              neededForBoot = true;
            };
            "/swap" = lib.mkDefault {
              device = "/dev/disk/by-label/${hostname}";
              fsType = "btrfs";
              options = [
                "subvol=swap"
                "noatime"
              ];
            };
          };
        }
      );
    };
}
