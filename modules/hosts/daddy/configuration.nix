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
        ++ [
          inputs.disko.nixosModules.disko
          inputs.kasha.nixosModules.box
        ];

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
      sops.secrets.kasha-env = {
        sopsFile = ../../../secrets/hosts/daddy.yaml;
        restartUnits = [ "kasha.service" ];
      };

      # The LAN kasha box, served as kasha.lan.zebradil.dev through traefik on
      # junior (a selector-less k3s Service points at this host). The store is
      # rebuildable from the remote cache and upstreams, so it lives on the HDD.
      services.kasha-box = {
        enable = true;
        # A btrfs subvolume made by hand: tmpfiles creates subvolumes only when
        # / is one, and here / is ext4, so on a fresh disk it would be a plain
        # directory.
        dataDir = "/srv/hdd/kasha";
        trustedKeys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "kasha-ci-1:KNW/sz+Zz800U/IFZ38vH5rvlHtM3Fb0Q/wmDJquG+U="
          "znix.zebradil.dev:nvr0OQFRddbHGopQbyLbLXQnntFBDKp23tqQq+msppw="
          "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
          "cache.flakehub.com-4:Asi8qIv291s0aYLyH6IOnr5Kf6+OF14WVjkE6t3xMio="
          "cache.flakehub.com-5:zB96CRlL7tiPtzA9/WKyPkp3A2vqxqgdgyTVNGShPDU="
          "cache.flakehub.com-6:W4EGFwAGgBj3he7c5fNh9NkOXw0PUVaxygCVKeuvaqU="
          "cache.flakehub.com-7:mvxJ2DZVHn/kRxlIaxYNMuDG1OvMckZu32um1TadOR8="
          "cache.flakehub.com-8:moO+OVS0mnTjBTcOUh2kYLQEd59ExzyoW1QgQ8XAARQ="
          "cache.flakehub.com-9:wChaSeTI6TeCuV/Sg2513ZIM9i0qJaYsF+lZCXg0J6o="
          "cache.flakehub.com-10:2GqeNlIp6AKp4EF2MVbE1kBOp9iBSyo0UPR9KoR0o1Y="
        ];
        environment = {
          KASHA_UPSTREAMS = "https://cache.nixos.org,https://install.determinate.systems";
          KASHA_PULL_THROUGH = "true";
          KASHA_REENCODE = "true";
        };
        # KASHA_TOKEN, AWS_* and KASHA_REMOTE (its endpoint names the R2 account).
        environmentFile = config.sops.secrets.kasha-env.path;
      };
      systemd.services.kasha.serviceConfig.MemoryMax = "3G";
      # Only the k3s nodes (junior, d1-d3) reach the box directly: traefik
      # proxies kasha.lan.zebradil.dev to it and vmagent scrapes it, both
      # masqueraded to their node IP. Clients go through traefik's HTTPS, so the
      # write token never crosses the LAN in plain HTTP.
      networking.firewall.extraCommands = ''
        for ip in 192.168.0.100 192.168.0.111 192.168.0.112 192.168.0.113; do
          iptables -A nixos-fw -p tcp -s "$ip" --dport 5000 -j nixos-fw-accept
        done
      '';

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
          # Unit states feed NodeSystemdServiceFailed, the signal for a failed
          # monthly btrfs scrub.
          enabledCollectors = [ "systemd" ];
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
