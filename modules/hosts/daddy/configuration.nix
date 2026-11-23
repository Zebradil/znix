{ inputs, ... }:
{
  # daddy — homelab appliance for host-bound, expendable workloads: Nix remote
  # builder now; kasha box and Jellyfin later. Durable data stays on the
  # Synology; the single HDD here holds only what can be lost or re-fetched.
  flake.modules.nixos.daddy =
    { config, lib, ... }:
    let
      ip = "192.168.0.101";
      iface = "enp6s0";
      kashaHost = "kasha.lan.zebradil.dev";
      secrets = ../../../secrets/hosts/daddy.yaml;
    in
    {
      imports =
        (with inputs.self.modules.nixos; [
          boot
          cloudflare-dynamic-dns
          daddy-disko
          daddy-hardware
          gdrive-nas-sync
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

        # Google Drive copy on the Synology, browsed and searched there; the
        # share keeps history with daily NAS-side Btrfs snapshots.
        gdriveNasSync = {
          enable = true;
          sopsFile = secrets;
          host = "192.168.0.30";
          user = "gdrive-sync";
          hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICAaNQAP193p1z1JbT/AfWlEg0h6mUcY78J4rr7hRSoU";
          target = "/gdrive";
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
              # Beats the *.lan.zebradil.dev wildcard (junior's traefik).
              # LAN resolvers see it only because AdGuard exempts the name.
              kasha = {
                domains = [ kashaHost ];
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

      # One sops key per value; env files are assembled here, so a value never
      # has to be edited as part of a multi-line blob.
      sops.secrets =
        lib.genAttrs
          [
            "aws-access-key-id"
            "aws-secret-access-key"
            "kasha-token"
            "kasha-remote"
            "acme-email"
            "acme-cloudflare-token"
          ]
          (_: {
            sopsFile = secrets;
          })
        // {
          tailscale-authkey.sopsFile = ../../../secrets/hosts/k3s.yaml;
        };
      sops.templates = with config.sops.placeholder; {
        kasha-env = {
          # KASHA_REMOTE is here too: its endpoint names the R2 account.
          content = ''
            AWS_ACCESS_KEY_ID=${aws-access-key-id}
            AWS_SECRET_ACCESS_KEY=${aws-secret-access-key}
            KASHA_TOKEN=${kasha-token}
            KASHA_REMOTE=${kasha-remote}
          '';
          restartUnits = [ "kasha.service" ];
        };
        acme-env.content = ''
          LEGO_EMAIL=${acme-email}
          CLOUDFLARE_DNS_API_TOKEN=${acme-cloudflare-token}
        '';
      };

      # The LAN kasha box, served directly as kasha.lan.zebradil.dev: caddy
      # terminates TLS and streams to kasha without buffering NARs on the SSD.
      # The store is rebuildable from the remote cache and upstreams, so it
      # lives on the HDD.
      security.acme = {
        acceptTerms = true;
        certs.${kashaHost} = {
          dnsProvider = "cloudflare";
          # Check propagation at the zone's authoritative server: the LAN split
          # horizon hides _acme-challenge TXTs, and a public recursive resolver
          # caches an early NXDOMAIN for the SOA's 1800 s negative TTL, far past
          # lego's 2-minute wait.
          dnsResolver = "lee.ns.cloudflare.com:53";
          environmentFile = config.sops.templates.acme-env.path;
        };
      };
      services.caddy = {
        enable = true;
        virtualHosts.${kashaHost} = {
          useACMEHost = kashaHost;
          extraConfig = "reverse_proxy ${config.services.kasha-box.listen}";
        };
      };
      networking.firewall.allowedTCPPorts = [ 443 ];

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
        environmentFile = config.sops.templates.kasha-env.path;
      };
      systemd.services.kasha.serviceConfig.MemoryMax = "3G";
      # Plain HTTP only for the k3s nodes (junior, d1-d3): vmagent scrapes the
      # box by IP, masqueraded to its node IP, so monitoring does not depend on
      # DNS or caddy. Clients use caddy's HTTPS, so the write token never
      # crosses the LAN in plain HTTP.
      networking.firewall.extraCommands = ''
        for ip in 192.168.0.100 192.168.0.111 192.168.0.112 192.168.0.113; do
          iptables -A nixos-fw -p tcp -s "$ip" --dport 5000 -j nixos-fw-accept
        done
      '';

      # The k3s ingress keeps Jellyfin's URLs and TLS and forwards to :8096.
      # The library lives on the HDD, re-fetchable like everything there.
      services.jellyfin = {
        enable = true;
        openFirewall = true;
        hardwareAcceleration = {
          enable = true;
          type = "nvenc";
          device = "/dev/nvidia0";
        };
        # Transcoding is set here, not in the dashboard.
        forceEncodingConfig = true;
        # What the GTX 1070 Ti (GP104) decodes and encodes in hardware.
        transcoding = {
          enableHardwareEncoding = true;
          hardwareDecodingCodecs = {
            h264 = true;
            hevc = true;
            hevc10bit = true;
            mpeg2 = true;
            vc1 = true;
            vp8 = true;
            vp9 = true;
          };
          hardwareEncodingCodecs.hevc = true;
        };
      };
      # CUDA filters and NVENC open these besides the card node.
      systemd.services.jellyfin.serviceConfig.DeviceAllow = [
        "/dev/nvidiactl rw"
        "/dev/nvidia-uvm rw"
        "/dev/nvidia-uvm-tools rw"
      ];

      # memtest from the boot menu avoids needing a USB stick on the headless box.
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
