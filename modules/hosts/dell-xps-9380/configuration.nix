{ inputs, ... }:
{
  # Shared base for the Dell XPS 9380 machines.
  flake.modules.nixos.dell-xps-9380 =
    { config, pkgs, ... }:
    {
      imports =
        (with inputs.self.modules.nixos; [
          adguard
          boot
          cloudflare-dynamic-dns
          dell-xps-9380-disko
          dell-xps-9380-hardware
          iperf3-server
          k3s-agent
          k3s-node
          nix-builder-client
          nix-settings
          openssh
          pki
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
      # 24/7 behind the closed lid. Blank the console after 60s of inactivity.
      boot.kernelParams = [ "consoleblank=60" ];

      # The kernel's default VT blank level only blacks out the framebuffer:
      # i915 keeps the eDP pipe and backlight running. VESA powerdown mode makes
      # the idle blank turn the pipe and backlight off. A keypress on the
      # console wakes it.
      systemd.services.console-powerdown = {
        description = "Power the panel down when the console blanks";
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.util-linux ];
        serviceConfig.Type = "oneshot";
        # vesa_blank_mode is global, but the ioctl must target a VT.
        # setterm refuses to run without a terminal type; units get no $TERM.
        # A console already blanked keeps its old blank mode until it is
        # unblanked, so poke it awake and force a fresh powerdown blank.
        script = ''
          s() { setterm --term linux "$@" </dev/tty1 >/dev/tty1; }
          s --powersave powerdown
          s --blank poke
          s --blank force
        '';
      };

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
