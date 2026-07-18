{ inputs, ... }:
{
  # Shared base for the Dell XPS 9380 machines.
  flake.modules.nixos.dell-xps-9380 =
    { config, ... }:
    {
      imports =
        (with inputs.self.modules.nixos; [
          boot
          cloudflare-dynamic-dns
          dell-xps-9380-disko
          dell-xps-9380-hardware
          k3s-agent
          nix-settings
          openssh
          sops
          suok
          wireless-headless
        ])
        ++ [ inputs.disko.nixosModules.disko ];

      znix = {
        boot.enable = true;
        wirelessHeadless.enable = true;
        k3sAgent.enable = true;

        cloudflareDynamicDns = {
          enable = true;
          configs.lan = {
            domains = [ "${config.networking.hostName}.lan.zebradil.dev" ];
            iface = "wlan0";
            stack = "ipv4";
          };
        };
      };

      system.stateVersion = "26.11";

      time.timeZone = "Europe/Berlin";
      i18n.defaultLocale = "en_US.UTF-8";

      # Headless with the lid closed: nothing must ever suspend. Mask the sleep
      # targets and tell logind to ignore the lid on every power source.
      systemd.targets = {
        sleep.enable = false;
        suspend.enable = false;
        hibernate.enable = false;
        hybrid-sleep.enable = false;
      };
      services.logind.settings.Login = {
        HandleLidSwitch = "ignore";
        HandleLidSwitchExternalPower = "ignore";
        HandleLidSwitchDocked = "ignore";
      };
    };
}
