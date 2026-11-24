_: {
  # One-way copy of Google Drive to a NAS share over SFTP. Drive is the only
  # place files are written; the NAS copy is for browsing, search and restore,
  # and keeps history through NAS-side snapshots, not here.
  flake.modules.nixos.gdrive-nas-sync =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.znix.gdriveNasSync;
      ph = config.sops.placeholder;
    in
    {
      options.znix.gdriveNasSync = {
        enable = lib.mkEnableOption "nightly rclone sync from Google Drive to a NAS share";

        sopsFile = lib.mkOption {
          type = lib.types.path;
          description = "sops file holding `gdrive-client-id`, `gdrive-client-secret`, `gdrive-token` and `gdrive-nas-ssh-key`.";
        };

        host = lib.mkOption {
          type = lib.types.str;
          description = "NAS address.";
        };

        user = lib.mkOption {
          type = lib.types.str;
          description = "NAS account allowed only SFTP and write access to the target share.";
        };

        hostKey = lib.mkOption {
          type = lib.types.str;
          example = "ssh-ed25519 AAAA…";
          description = "The NAS's ed25519 SSH host key (`ssh-keyscan -t ed25519 <host>`).";
        };

        target = lib.mkOption {
          type = lib.types.str;
          example = "/gdrive";
          description = "Path of the share as the SFTP server shows it.";
        };

        onCalendar = lib.mkOption {
          type = lib.types.str;
          default = "03:00";
          description = "systemd OnCalendar expression for the sync.";
        };
      };

      config = lib.mkIf cfg.enable {
        sops.secrets =
          lib.genAttrs
            [
              "gdrive-client-id"
              "gdrive-client-secret"
              "gdrive-token"
              "gdrive-nas-ssh-key"
            ]
            (_: {
              inherit (cfg) sopsFile;
            });

        sops.templates."gdrive-nas-sync-rclone.conf".content = ''
          [gdrive]
          type = drive
          scope = drive
          client_id = ${ph.gdrive-client-id}
          client_secret = ${ph.gdrive-client-secret}
          token = ${ph.gdrive-token}

          [nas]
          type = sftp
          host = ${cfg.host}
          user = ${cfg.user}
          known_hosts_file = ${pkgs.writeText "gdrive-nas-known-hosts" "${cfg.host} ${cfg.hostKey}\n"}
          host_key_algorithms = ${lib.head (lib.splitString " " cfg.hostKey)}
          # Synology SFTP gives the account no shell, so rclone cannot run md5sum there.
          shell_type = none
        '';

        systemd.services.gdrive-nas-sync = {
          description = "rclone sync Google Drive to NAS";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            DynamicUser = true;
            RuntimeDirectory = "gdrive-nas-sync";
            LoadCredential = [
              "rclone.conf:${config.sops.templates."gdrive-nas-sync-rclone.conf".path}"
              "nas-key:${config.sops.secrets.gdrive-nas-ssh-key.path}"
            ];
            Nice = 10;
            IOSchedulingClass = "idle";
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = true;
          };
          environment.RCLONE_CONFIG_NAS_KEY_FILE = "%d/nas-key";
          # rclone writes refreshed access tokens back to its config, so it gets
          # a writable copy; the refresh token in sops stays valid.
          script = ''
            install -m 600 "$CREDENTIALS_DIRECTORY/rclone.conf" "$RUNTIME_DIRECTORY/rclone.conf"
            # Synology shows its read-only Btrfs snapshots at the share root as #snapshot;
            # without the exclude, sync walks every snapshot and fails deleting from them.
            exec ${lib.getExe pkgs.rclone} sync gdrive: nas:${cfg.target} \
              --exclude "/#snapshot/**" \
              --config "$RUNTIME_DIRECTORY/rclone.conf" \
              --drive-acknowledge-abuse --fast-list --stats 10m --stats-log-level NOTICE -v
          '';
        };

        systemd.timers.gdrive-nas-sync = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = cfg.onCalendar;
            Persistent = true;
          };
        };
      };
    };
}
