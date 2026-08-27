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

        # iwd's autoconnect_quick path probes only the frequencies cached in
        # /var/lib/iwd/.known_network.freq, in file order, and takes the first usable BSS —
        # on a multi-AP SSID that parks it on whichever AP happens to be listed first,
        # ignoring signal. The stock thresholds (-70 / -76) are too low for a
        # mediocre-but-usable link to ever trigger the corrective roam scan.
        # See docs/wifi-troubleshooting.md.
        networking.wireless.iwd.settings.General = {
          RoamThreshold = -55;
          RoamThreshold5G = -65;
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
