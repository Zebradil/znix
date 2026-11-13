{ inputs, ... }:
{
  # daddy — homelab appliance for host-bound, expendable workloads: Nix remote
  # builder now; kasha box and Jellyfin later. Durable data stays on the
  # Synology; the single HDD here holds only what can be lost or re-fetched.
  flake.modules.nixos.daddy =
    { config, ... }:
    let
      ip = "192.168.0.101";
      iface = "enp6s0";
    in
    {
      imports =
        (with inputs.self.modules.nixos; [
          boot
          cloudflare-dynamic-dns
          daddy-disko
          daddy-hardware
          nix-builder-server
          nix-settings
          openssh
          pki
          sops
          suok
          tailscale
        ])
        ++ [ inputs.disko.nixosModules.disko ];

      znix = {
        boot.enable = true;

        tailscale = {
          enable = true;
          advertiseTags = [ "tag:k3s" ];
          authKeyFile = config.sops.secrets.tailscale-authkey.path;
        };

        cloudflareDynamicDns = {
          enable = true;
          configs =
            let
              n = config.networking.hostName;
            in
            {
              lan = {
                domains = [
                  "${n}.lan.zebradil.dev"
                  "*.${n}.lan.zebradil.dev"
                ];
                inherit iface;
                stack = "ipv4";
              };
              ts = {
                domains = [
                  "${n}.ts.zebradil.dev"
                  "*.${n}.ts.zebradil.dev"
                ];
                iface = "tailscale0";
                stack = "ipv4";
              };
            };
        };
      };

      sops.secrets.tailscale-authkey.sopsFile = ../../../secrets/hosts/k3s.yaml;

      # RAM is unverified (only half of the installed 48 GB maps); memtest from
      # the boot menu avoids needing a USB stick on the headless box.
      boot.loader.systemd-boot.memtest86.enable = true;

      # Whole-disk btrfs (no partition table) carried over from the old desktop.
      # nofail: the HDD holds no boot-critical state, so a dead disk must not
      # block boot and SSH access.
      fileSystems."/srv/hdd" = {
        device = "/dev/disk/by-uuid/c50733b4-ace5-4715-aa67-5c63e3fbfac7";
        fsType = "btrfs";
        options = [
          "noatime"
          "compress=zstd"
          "nofail"
        ];
      };
      services.btrfs.autoScrub = {
        enable = true;
        fileSystems = [ "/srv/hdd" ];
        interval = "monthly";
      };

      # Scraped by the cluster's vmagent. SSD wear (MX500 attribute 202) and HDD
      # sector health are the alerts that matter on this box.
      services.prometheus.exporters = {
        node = {
          enable = true;
          openFirewall = true;
        };
        smartctl = {
          enable = true;
          openFirewall = true;
        };
      };

      networking = {
        hostName = "daddy";
        domain = "zebradil.dev";
        # Search `lan` rather than `zebradil.dev` so unresolved local subdomains
        # (like kasha.lan.zebradil.dev on AAAA) don't search .zebradil.dev and hit
        # Cloudflare's public wildcard (#237).
        search = [ "lan" ];
        useDHCP = false;
        nameservers = [ "192.168.0.1" ];
      };
      services.resolved.enable = false;
      systemd.network = {
        enable = true;
        networks."10-${iface}" = {
          matchConfig.Name = iface;
          address = [ "${ip}/16" ];
          routes = [ { Gateway = "192.168.0.1"; } ];
        };
      };

      system.stateVersion = "26.11";
      time.timeZone = "Europe/Berlin";
      i18n.defaultLocale = "en_US.UTF-8";
    };
}
