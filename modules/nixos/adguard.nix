_: {
  flake.modules.nixos.adguard =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.znix.adguard;
      uiPort = 3000;
    in
    {
      options.znix.adguard = {
        enable = lib.mkEnableOption "AdGuard Home as the LAN resolver";

        serviceAddress = lib.mkOption {
          type = lib.types.str;
          default = "192.168.0.53";
          description = ''
            IPv4 address the resolver answers on, and the only address AdGuard
            binds. Handed to clients as DHCP option 6. A second instance takes a
            different address: both run identical filtering from this module, so
            a client picking either one gets the same answers.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        # The service address lives on a dummy link so it survives a dead cable.
        # `dual-net` keeps the host reachable over WiFi when the wired link
        # drops, but an address on that wired link would drop with it and take
        # DNS down on a host that is otherwise perfectly up. A dummy link never
        # flaps, and Linux's default weak host model (arp_ignore = 0) answers
        # ARP for the address out of whichever link the request arrived on.
        systemd.network = {
          enable = true;
          netdevs."05-dns0".netdevConfig = {
            Name = "dns0";
            Kind = "dummy";
          };
          networks."05-dns0" = {
            matchConfig.Name = "dns0";
            address = [ "${cfg.serviceAddress}/32" ];
            # Carries no route anywhere; must not hold up wait-online.
            linkConfig.RequiredForOnline = "no";
          };
        };

        # `arp_ignore = 0` lets whichever link a request arrived on answer for
        # the service address — but it never tells a client which link is
        # *live*. On a dual-net host both links answer, so a client caches
        # whichever reply won the race and then keeps that entry alive by
        # unicast-probing the same MAC. Land on the standby link's MAC while
        # that path is unhealthy and DNS blackholes for that client alone until
        # its ARP cache ages out (20 minutes on macOS) — the resolver looks
        # perfectly healthy throughout, and restarting it changes nothing. The
        # same gap makes a real wired-link failover invisible to every client
        # that already has an entry.
        #
        # A gratuitous ARP out the link currently holding the default route
        # repins every cache to the live path. Route metrics (`dual-net`) make
        # that wired while wired is up, WiFi otherwise, so no health check is
        # needed here either.
        systemd.services.dns-garp = {
          description = "Gratuitous ARP for ${cfg.serviceAddress} out the active link";
          serviceConfig.Type = "oneshot";
          path = [
            pkgs.iputils
            pkgs.iproute2
          ];
          script = ''
            set -- $(ip -o route show default | head -n1)
            while [ $# -gt 0 ] && [ "$1" != "dev" ]; do shift; done
            dev=$2
            [ -n "$dev" ] || exit 0
            # -s: the address lives on dns0, never on the announcing link.
            arping -c 2 -U -I "$dev" -s ${cfg.serviceAddress} ${cfg.serviceAddress}
          '';
        };

        systemd.timers.dns-garp = {
          wantedBy = [ "timers.target" ];
          # Bounds both a failover and a wrongly-cached MAC to one interval.
          timerConfig = {
            OnBootSec = "30s";
            OnUnitActiveSec = "30s";
          };
        };

        # AdGuard owns :53, so the systemd-resolved stub listener must not.
        services.resolved.enable = lib.mkDefault false;

        # These allow traffic that is already destined for `serviceAddress` —
        # the bind below is what keeps the resolver off the host's public IPv6.
        # Without that bind, opening :53 here would publish an open resolver.
        networking.firewall = {
          allowedTCPPorts = [
            53
            uiPort
          ];
          allowedUDPPorts = [ 53 ];
        };

        # The module's own ordering is `after = network.target`, which does not
        # guarantee dns0 exists — and AdGuard binds exactly one address, so
        # losing that race is a failed start. `Restart = always` would recover
        # it in 10s; ordering means it does not happen.
        systemd.services.adguardhome = {
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
        };

        services.adguardhome = {
          enable = true;
          # Config is owned by Nix; the web UI is effectively read-only.
          mutableSettings = false;
          # Would open only the UI port, and the rules above already cover it.
          openFirewall = false;
          # Sets `settings.http.address` — the UI binds the service address too,
          # so it is unreachable from anywhere but the LAN.
          host = cfg.serviceAddress;
          port = uiPort;

          settings = {
            # Admin UI login. The hash is a bcrypt of a random, throwaway
            # password unique to this LAN-only UI (repo is public — never inline
            # a reused credential's hash). Rotate freely in the UI; this only
            # seeds it.
            users = [
              {
                name = "zebradil";
                password = "$2b$05$6PpI3aocODD1I/UTkVmxUO0xQ6PckIAhmby1KDi7e/koKPrNXbI5i";
              }
            ];

            dns = {
              bind_hosts = [ cfg.serviceAddress ];
              port = 53;
              # AdGuard's default is 20 QPS, and `ratelimit_subnet_len_ipv4`
              # defaults to 24 — so the whole 192.168.1.0/24 shares one bucket
              # and a single browser burst silently drops every other client's
              # queries (no reply, no query-log entry: a bare dig timeout).
              # The limit exists to keep an open resolver from being a
              # DDoS amplifier; here the bind above and the firewall do that.
              ratelimit = 0;
              upstream_dns = [
                "[/lan/] 192.168.0.1" # local `lan` names -> router
                "8.8.4.4"
                "1.0.0.1"
                "9.9.9.9"
              ];
              upstream_mode = "load_balance";
              bootstrap_dns = [
                "9.9.9.10"
                "149.112.112.10"
                "2620:fe::10"
                "2620:fe::fe:10"
              ];
              enable_dnssec = true;
              cache_enabled = true;
              cache_size = 32000000;
              cache_optimistic = true;
              use_private_ptr_resolvers = true;
            };

            filters = [
              {
                enabled = true;
                url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt";
                name = "AdGuard DNS filter";
                id = 1;
              }
              {
                enabled = false;
                url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt";
                name = "AdAway Default Blocklist";
                id = 2;
              }
            ];

            # Split-horizon for the homelab. On the LAN, the canonical
            # <svc>.zebradil.dev names resolve to the LAN ingress (fast, no OIDC)
            # instead of the Cloudflare-proxied public path. Off-LAN clients use
            # other resolvers and keep hitting the public (authenticated) path.
            #
            # CNAME to lan.zebradil.dev rather than a hardcoded IP: that record is
            # DDNS-managed and aggregates the LAN edge IP(s), so adding an edge
            # needs no change here. It has no AAAA, which forces dual-stack clients
            # onto IPv4 and off the public IPv6 path (the AAAA trap).
            #
            # The rewrites *table* can't express exclusions, so these are
            # AdBlock-style $dnsrewrite rules. @@ exempts names that must resolve
            # normally: znix (CNAME to R2) and the .ts debug names. No other
            # resolver in this class can express the exemption — blocky's
            # customDNS covers subdomains with no way to carve names back out
            # (0xERR0R/blocky#1631, closed as not planned), which is why this
            # stayed on AdGuard.
            user_rules = [
              "||zebradil.dev^$dnsrewrite=NOERROR;CNAME;lan.zebradil.dev"
              "@@|zebradil.dev^$dnsrewrite"
              "@@||znix.zebradil.dev^$dnsrewrite"
              "@@||ts.zebradil.dev^$dnsrewrite"
            ];

            querylog = {
              enabled = true;
              interval = "2160h";
            };
            statistics = {
              enabled = true;
              interval = "2160h";
            };
          };
        };
      };
    };
}
