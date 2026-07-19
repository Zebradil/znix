_: {
  flake.modules.nixos.wireless-headless =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.znix.wirelessHeadless;
    in
    {
      options.znix.wirelessHeadless = {
        enable = lib.mkEnableOption "headless WiFi (networkd + iwd, static address)";
        address = lib.mkOption {
          type = lib.types.str;
          example = "192.168.0.110/24";
          description = "Static IPv4 CIDR for the WiFi link.";
        };
        gateway = lib.mkOption {
          type = lib.types.str;
          default = "192.168.0.1";
          description = "Default gateway / router. Also used as the DNS server.";
        };
      };

      config = lib.mkIf cfg.enable {
        networking = {
          useDHCP = false;
          wireless.iwd.enable = true;
          nameservers = [ cfg.gateway ];
        };

        services.resolved.enable = false;

        systemd.network = {
          enable = true;
          networks."10-wlan" = {
            matchConfig.Type = "wlan";
            address = [ cfg.address ];
            routes = [ { Gateway = cfg.gateway; } ];
          };
        };

        # iwd stores the derived PreSharedKey next to the file; make sure the
        # dir exists before iwd starts (sops renders the file into it).
        systemd.tmpfiles.rules = [ "d /var/lib/iwd 0700 root root -" ];

        sops.secrets.dust-psk.sopsFile = ../../secrets/hosts/k3s.yaml;
        sops.templates."iwd-dust" = {
          # iwd's known-network file. Presence => autoconnect on boot.
          path = "/var/lib/iwd/DUST.psk";
          mode = "0600";
          restartUnits = [ "iwd.service" ];
          content = ''
            [Security]
            Passphrase=${config.sops.placeholder.dust-psk}
          '';
        };
      };
    };
}
