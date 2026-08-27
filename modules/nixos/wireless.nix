_: {
  flake.modules.nixos.wireless =
    {
      config,
      lib,
      ...
    }:
    {
      options.znix.wireless.enable = lib.mkEnableOption "wireless networking";

      config = lib.mkIf config.znix.wireless.enable {
        hardware.bluetooth.enable = true;
        services = {
          blueman.enable = true;
          # TODO: udisks2 and resolved aren't related to wireless services, they should be moved out
          udisks2.enable = true;
          resolved = {
            enable = true;
            settings.Resolve = {
              DNSSEC = "true";
              FallbackDNS = [
                "1.1.1.1"
                "8.8.8.8"
              ];
            };
          };
        };

        sops.secrets.wireless = {
          sopsFile = ../../secrets/hosts/common.yaml;
        };

        sops.templates."wifi-env".content = ''
          WIFI_PSK=${config.sops.placeholder.wireless}
        '';

        # On a multi-AP SSID, iwd can end up on a distant AP — its autoconnect_quick path only
        # probes the frequencies cached in /var/lib/iwd/.known_network.freq, and a BSS that
        # recently failed to associate is skipped even when it is by far the strongest. The
        # stock thresholds (-70 / -76) are low enough that the resulting mediocre-but-usable
        # link never triggers a corrective roam scan. See docs/wifi-troubleshooting.md.
        networking.wireless.iwd.settings = {
          General = {
            RoamThreshold = -55;
            RoamThreshold5G = -65;
          };

          # iwd ranks candidate BSSes by the data rate it estimates from their RSSI, so a
          # close 2.4 GHz radio can outrank a 5 GHz one that is still perfectly usable.
          # Halving the 2.4 GHz rank leaves it as a fallback for when 5 GHz is genuinely
          # bad. Not 0.0 — that disables the band outright, scanning included.
          Rank.BandModifier2_4GHz = "0.5";
        };

        networking.networkmanager = {
          enable = true;
          wifi.backend = "iwd";
          ensureProfiles = {
            environmentFiles = [ config.sops.templates."wifi-env".path ];
            profiles = lib.genAttrs [ "DUST" ] (ssid: {
              connection = {
                id = ssid;
                type = "wifi";
              };
              wifi = {
                inherit ssid;
                mode = "infrastructure";
              };
              wifi-security = {
                key-mgmt = "wpa-psk";
                psk = "$WIFI_PSK";
              };
              ipv4.method = "auto";
              ipv6.method = "auto";
            });
          };
        };

        environment.persistence."/persist".directories = [
          "/etc/NetworkManager/system-connections"
          "/var/lib/bluetooth"
        ];
      };
    };
}
