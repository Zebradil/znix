{ inputs, ... }:
{
  # junior — the single k3s server (control plane) for the homelab cluster.
  # An appliance: bespoke wired mini-PC, its identity (CA + SQLite datastore)
  # is preserved state, so no impermanence. Also a worker (schedulable), hence
  # the shared k3s-node plumbing.
  flake.modules.nixos.junior =
    { config, ... }:
    let
      # Load-bearing address: agents dial it, three tls-sans cover it, and the
      # controller/scheduler bind to it. Static so k3s never races a DHCP lease
      # on boot and fails to bind.
      ip = "192.168.0.100";
    in
    {
      imports =
        (with inputs.self.modules.nixos; [
          boot
          cloudflare-dynamic-dns
          junior-disko
          junior-hardware
          k3s-node
          nix-settings
          openssh
          sops
          suok
          tailscale
        ])
        ++ [ inputs.disko.nixosModules.disko ];

      znix = {
        boot.enable = true;
        k3sNode = {
          enable = true;
          selfLan = ip;
          selfVpn = "100.85.146.64"; # junior-1, the tagged tailnet identity
        };

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
                iface = "eno1";
                stack = "ipv4";
              };
              wan = {
                domains = [
                  "${n}.zebradil.dev"
                  "*.${n}.zebradil.dev"
                ];
                iface = "eno1";
                stack = "ipv6";
              };
              ts = {
                domains = [
                  "${n}.ts.zebradil.dev"
                  "*.${n}.ts.zebradil.dev"
                ];
                iface = "tailscale0";
                stack = "ipv4";
              };
              lan-multi = {
                domains = [
                  "lan.zebradil.dev"
                  "*.lan.zebradil.dev"
                ];
                iface = "eno1";
                stack = "ipv4";
                multihost = true;
              };
              wan-multi = {
                domains = [
                  "zebradil.dev"
                  "*.zebradil.dev"
                ];
                iface = "eno1";
                stack = "ipv6";
                multihost = true;
                proxy = "enabled";
              };
              ts-multi = {
                domains = [
                  "ts.zebradil.dev"
                  "*.ts.zebradil.dev"
                ];
                iface = "tailscale0";
                stack = "ipv4";
                multihost = true;
              };
            };
        };
      };

      # OAuth client secret for unattended Tailscale auth (advertises tag:k3s).
      sops.secrets.tailscale-authkey.sopsFile = ../../../secrets/hosts/k3s.yaml;

      # k3s server. k3s-node already set enable/package/tokenFile; here we add
      # the control-plane role and the flags captured verbatim from the Debian
      # unit — any drift silently reshapes the cluster.
      services.k3s = {
        role = "server";
        extraFlags = [
          "--tls-san=k8s.junior.zebradil.dev"
          "--tls-san=k8s.junior.lan.zebradil.dev"
          "--tls-san=k8s.junior.ts.zebradil.dev"
          "--disable-helm-controller"
          "--disable=traefik"
          "--disable=servicelb"
          "--etcd-expose-metrics=true"
          "--kube-controller-manager-arg=bind-address=${ip}"
          "--kube-scheduler-arg=bind-address=${ip}"
        ];
      };

      # Static wired networking on the onboard NIC (matched by name — one fixed
      # onboard e1000e). DNS from the router; resolved off (matches the fleet).
      networking = {
        hostName = "junior";
        domain = "zebradil.dev";
        useDHCP = false;
        nameservers = [ "192.168.0.1" ];

        # apiserver, on top of the worker ports opened by k3s-node.
        firewall.allowedTCPPorts = [
          80
          443
          6443
        ];
      };
      services.resolved.enable = false;
      systemd.network = {
        enable = true;
        networks."10-eno1" = {
          matchConfig.Name = "eno1";
          address = [ "${ip}/16" ];
          routes = [ { Gateway = "192.168.0.1"; } ];
        };
      };

      system.stateVersion = "26.11";
      time.timeZone = "Europe/Berlin";
      i18n.defaultLocale = "en_US.UTF-8";
    };
}
