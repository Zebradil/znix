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
          k3s-node
          nix-settings
          openssh
          sops
          suok
          tailscale
          dual-net
        ])
        ++ [ inputs.disko.nixosModules.disko ];

      znix = {
        boot.enable = true;
        dualNet.enable = true;
        k3sAgent.enable = true;

        tailscale = {
          enable = true;
          advertiseTags = [ "tag:k3s" ];
          authKeyFile = config.sops.secrets.tailscale-authkey.path;
        };

        cloudflareDynamicDns = {
          enable = true;
          configs.lan = {
            domains = [ "${config.networking.hostName}.lan.zebradil.dev" ];
            # Static wired IP (same value k3s advertises as node.k8s.lan). Read
            # as a constant, not off an interface, so the record stays correct
            # regardless of which link is up.
            ipcmd = "echo ${config.znix.k3sNode.selfLan}";
            stack = "ipv4";
          };
        };
      };

      # OAuth client secret for unattended Tailscale auth (advertises tag:k3s).
      sops.secrets.tailscale-authkey.sopsFile = ../../../secrets/hosts/k3s.yaml;

      system.stateVersion = "26.11";

      time.timeZone = "Europe/Berlin";
      i18n.defaultLocale = "en_US.UTF-8";

      # Headless: the panel is otherwise never idle-blanked, so it stays lit
      # 24/7 behind the closed lid. Blank the console after 60s of inactivity,
      # which powers the internal backlight off.
      boot.kernelParams = [ "consoleblank=60" ];

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
