_: {
  # Headless dual-link networking: wired (USB NIC) primary, WiFi hot standby.
  # Both links stay up; the kernel prefers wired via route metric and falls to
  # WiFi automatically when the wired carrier drops. No health-check daemon —
  # a dead route simply disappears and the next-lowest metric takes over.
  flake.modules.nixos.dual-net =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.znix.dualNet;
    in
    {
      options.znix.dualNet = {
        enable = lib.mkEnableOption "headless dual-link networking (networkd + iwd, wired primary, WiFi fallback)";
        address = lib.mkOption {
          type = lib.types.str;
          example = "192.168.0.110/24";
          description = "Static IPv4 CIDR for the wired (primary) link. This is the host's canonical/reachable address.";
        };
        fallbackAddress = lib.mkOption {
          type = lib.types.str;
          example = "192.168.0.120/24";
          description = "Static IPv4 CIDR for the WiFi fallback link. Unpublished; carries a higher-metric default route for recovery when wired is down.";
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

          # "Online" means reachable by *some* link. Without this, wait-online
          # blocks until every managed link is up, so a single dead cable would
          # hang boot on a box whose whole point is surviving one dead link.
          wait-online.anyInterface = true;

          networks = {
            # Wired USB NIC. Path=*usb* pins it to hardware on the USB bus,
            # excluding k3s's flannel/cni/veth interfaces (also Type=ether but
            # with no Path). Lower metric => preferred over WiFi.
            "20-wired" = {
              matchConfig = {
                Type = "ether";
                Path = "*usb*";
              };
              address = [ cfg.address ];
              routes = [
                {
                  Gateway = cfg.gateway;
                  Metric = 100;
                }
              ];
            };

            # WiFi hot standby. Higher metric => used only when wired is down.
            "10-wlan" = {
              matchConfig.Type = "wlan";
              address = [ cfg.fallbackAddress ];
              routes = [
                {
                  Gateway = cfg.gateway;
                  Metric = 600;
                }
              ];
            };
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
