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

      networking.hostName = "junior";
      networking.domain = "zebradil.dev";

      znix = {
        boot.enable = true;
        k3sNode = {
          enable = true;
          selfLan = ip; # 192.168.0.100
          selfVpn = "100.85.146.64"; # junior-1, the tagged tailnet identity
        };

        tailscale = {
          enable = true;
          advertiseTags = [ "tag:k3s" ];
          authKeyFile = config.sops.secrets.tailscale-authkey.path;
        };

        cloudflareDynamicDns = {
          enable = true;
          configs = {
            lan = {
              domains = [ "${config.networking.hostName}.lan.zebradil.dev" ];
              iface = "eno1";
              stack = "ipv4";
            };
            wan = {
              domains = [ "${config.networking.hostName}.zebradil.dev" ];
              iface = "eno1";
              stack = "ipv6";
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

      # apiserver, on top of the worker ports opened by k3s-node.
      networking.firewall.allowedTCPPorts = [
        80
        443
        6443
      ];

      # Static wired networking on the onboard NIC (matched by name — one fixed
      # onboard e1000e). DNS from the router; resolved off (matches the fleet).
      networking = {
        useDHCP = false;
        nameservers = [ "192.168.0.1" ];
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
