_: {
  # LAN DNS. Migrated from the old Docker container's AdGuardHome.yaml into a
  # declarative, read-only config. Host-scoped (single consumer) rather than a
  # fleet-wide module.
  flake.modules.nixos.toddler-adguard = {
    services.adguardhome = {
      enable = true;
      # Config is owned by Nix; the web UI is effectively read-only.
      mutableSettings = false;
      # Open the DNS (:53) and admin (:80) ports derived from settings.
      openFirewall = true;
      host = "0.0.0.0";
      port = 80;

      settings = {
        http.address = "0.0.0.0:80";

        # Admin UI login. The hash is a bcrypt of a random, throwaway password
        # unique to this LAN-only UI (repo is public — never inline a reused
        # credential's hash). Rotate freely in the UI; this only seeds it.
        users = [
          {
            name = "zebradil";
            password = "$2b$05$6PpI3aocODD1I/UTkVmxUO0xQ6PckIAhmby1KDi7e/koKPrNXbI5i";
          }
        ];

        dns = {
          bind_hosts = [ "0.0.0.0" ];
          port = 53;
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

        # SD-card wear: shorter retention than the old 90d, file-backed logs.
        # See DEFER-1 in docs/hosts/toddler.md for further mitigation.
        querylog = {
          enabled = true;
          interval = "168h"; # 7 days
        };
        statistics = {
          enabled = true;
          interval = "168h";
        };
      };
    };
  };
}
