_: {
  flake.modules.nixos.wireless =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.znix.wireless;
      secrets = lib.unique (lib.mapAttrsToList (_: net: net.pskSecret) cfg.networks);
      # ensureProfiles substitutes $VAR from the environment file, so the name must be a shell identifier.
      envVar =
        secret:
        "PSK_"
        + lib.concatMapStrings (c: if builtins.match "[A-Za-z0-9_]" c != null then c else "_") (
          lib.stringToCharacters secret
        );
    in
    {
      options.znix.wireless = {
        enable = lib.mkEnableOption "wireless networking";

        networks = lib.mkOption {
          description = ''
            WPA-PSK networks to declare as NetworkManager profiles, keyed by SSID.
            Networks joined ad hoc through nm-applet are saved alongside these in
            /etc/NetworkManager/system-connections.
          '';
          type = lib.types.attrsOf (
            lib.types.submodule {
              options.pskSecret = lib.mkOption {
                type = lib.types.str;
                description = "Key in secrets/hosts/common.yaml holding the passphrase.";
              };
            }
          );
          default = { };
        };
      };

      config = lib.mkIf cfg.enable {
        znix.wireless.networks.DUST.pskSecret = lib.mkDefault "wireless";

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

        sops.secrets = lib.genAttrs secrets (_: {
          sopsFile = ../../secrets/hosts/common.yaml;
        });

        sops.templates."wifi-env".content = lib.concatMapStrings (
          secret: "${envVar secret}=${config.sops.placeholder.${secret}}\n"
        ) secrets;

        networking.networkmanager = {
          enable = true;
          ensureProfiles = {
            environmentFiles = [ config.sops.templates."wifi-env".path ];
            profiles = lib.mapAttrs (ssid: net: {
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
                psk = "\$${envVar net.pskSecret}";
              };
              ipv4.method = "auto";
              ipv6.method = "auto";
            }) cfg.networks;
          };
        };

        environment.persistence."/persist".directories = [
          "/etc/NetworkManager/system-connections"
          "/var/lib/bluetooth"
        ];
      };
    };
}
