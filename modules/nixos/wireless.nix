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
        services.blueman.enable = true;

        sops.secrets.wireless = {
          sopsFile = ../../secrets/hosts/common.yaml;
        };

        sops.templates."wifi-env".content = ''
          WIFI_PSK=${config.sops.placeholder.wireless}
        '';

        networking.networkmanager = {
          enable = true;
          wifi.backend = "iwd";
          ensureProfiles = {
            environmentFiles = [ config.sops.templates."wifi-env".path ];
            profiles =
              lib.genAttrs
                [
                  "DUST"
                  "DUSTY"
                  "DUSK"
                ]
                (ssid: {
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

        services.resolved = {
          enable = true;
          settings.Resolve = {
            DNSSEC = "allow-downgrade";
            FallbackDNS = [
              "1.1.1.1"
              "8.8.8.8"
            ];
          };
        };

        environment.persistence."/persist".directories = [
          "/etc/NetworkManager/system-connections"
          "/var/lib/bluetooth"
        ];
      };
    };
}
