{ config, lib, ... }:
let
  nodeConfig = host: config.flake.nixosConfigurations.${host}.config;
  k3sNode = host: hostKey: {
    inherit hostKey;
    lan = (nodeConfig host).znix.k3sNode.selfLan;
    tailnet = (nodeConfig host).znix.k3sNode.selfVpn;
  };

  # Tailnet IPs rather than names: the ts.zebradil.dev wildcard resolves an
  # unpublished host to junior, and MagicDNS names need --accept-dns. An IP
  # changes only when a host is deleted from the tailnet and registers anew.
  hosts = {
    daddy = {
      lan = lib.head (
        lib.splitString "/" (lib.head (nodeConfig "daddy").systemd.network.networks."10-enp6s0".address)
      );
      tailnet = "100.115.144.94";
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIunTmGGD83WKotySV3vBD5aD/luU8p1sYCu8UxlyvwK";
    };
    junior = k3sNode "junior" "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMaqOxLFO1pP1TGiMKVGs5PFPgGZcnhExjtMVmVTOhYc";
    d1 = k3sNode "d1" "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIATZnTfglZ7nTAGZdcmtjTUhfjfgOOgciC+A4SFHTWk0";
    d2 = k3sNode "d2" "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK626ImCb3DXC5alsmgK1yt8GXJ2gyQ1gxrR7lyweGBi";
    d3 = k3sNode "d3" "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMx91ZNA3xd2XbT4ryR/I05saxJK8cymMvFz0YdRLWim";
  };
in
{
  flake.lib.sshHosts = hosts;

  # `ssh <host>` reaches a homelab host over the tailnet when it answers there
  # and over the LAN otherwise, so it works away from home and at home while
  # Tailscale is down. Probing the LAN address first would, on a foreign LAN
  # in the same range, reach a stranger's host; no client accepts the tailnet's
  # subnet routes, so the LAN address is reachable only from the LAN itself.
  # The key is pinned under the alias, so both paths check the same key.
  flake.modules.nixos.ssh-hosts =
    { pkgs, ... }:
    {
      programs.ssh.extraConfig = lib.concatStrings (
        lib.mapAttrsToList (name: h: ''
          Match originalhost ${name} exec "${pkgs.netcat}/bin/nc -z -w1 ${h.tailnet} 22"
            HostName ${h.tailnet}
          Host ${name}
            HostName ${h.lan}
            HostKeyAlias ${name}
        '') hosts
      );
      programs.ssh.knownHosts = lib.mapAttrs (_: h: { publicKey = h.hostKey; }) hosts;
    };
}
