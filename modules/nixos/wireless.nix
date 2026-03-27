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

        sops.secrets.wireless = {
          sopsFile = ../../secrets/hosts/common.yaml;
          owner = "wpa_supplicant";
          group = "wpa_supplicant";
        };

        networking.wireless = {
          enable = true;
          fallbackToWPA2 = false;
          secretsFile = config.sops.secrets.wireless.path;
          networks =
            lib.genAttrs
              [
                "DUST"
                "DUSTY"
                "DUSK"
              ]
              (_ssid: {
                pskRaw = "ext:psk_home";
              });

          allowAuxiliaryImperativeNetworks = true;
          userControlled = true;
        };

        users.groups.network = { };
      };
    };
}
