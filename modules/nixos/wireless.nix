{ ... }:
{
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
          neededForUsers = true;
        };

        networking.wireless = {
          enable = true;
          fallbackToWPA2 = false;
          secretsFile = config.sops.secrets.wireless.path;
          networks = lib.genAttrs [
            "DUST"
            "DUSTY"
            "DUSK"
          ] (_ssid: { pskRaw = "ext:psk_home"; });

          allowAuxiliaryImperativeNetworks = true;
          extraConfig = ''
            ctrl_interface=DIR=/run/wpa_supplicant GROUP=${config.users.groups.network.name}
            update_config=1
          '';
        };

        users.groups.network = { };
        systemd.services.wpa_supplicant.preStart = "touch /etc/wpa_supplicant.conf";
      };
    };
}
