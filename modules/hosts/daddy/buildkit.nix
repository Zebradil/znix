{ config, lib, ... }:
let
  inherit (config.flake.lib) sshHosts;
  port = 1234;
  clients = map (h: sshHosts.${h}.lan) [
    "junior"
    "d1"
    "d2"
    "d3"
  ];
in
{
  # Rootless BuildKit for the homelab CI runner pods (buildx `remote` driver).
  # Clients authenticate with a certificate from a one-off CA whose key was
  # discarded after issuing; rotating means a new CA, server and client
  # certificate (the client half lives in myks-homelab's arc-homelab secrets).
  flake.modules.nixos.daddy-buildkit =
    { config, pkgs, ... }:
    let
      settings = (pkgs.formats.toml { }).generate "buildkitd.toml" {
        root = "/var/lib/buildkit";
        grpc = {
          address = [ "tcp://0.0.0.0:${toString port}" ];
          tls = {
            cert = "${./buildkit/server.crt}";
            key = "/run/credentials/buildkit.service/server-key";
            ca = "${./buildkit/ca.crt}";
          };
        };
        worker.containerd.enabled = false;
        worker.oci = {
          enabled = true;
          rootless = true;
          # RUN steps share rootlesskit's namespace, so their traffic leaves
          # through slirp4netns as the buildkit user (see the egress chain).
          networkMode = "host";
          gc = true;
          reservedSpace = "10GB";
          maxUsedSpace = "100GB";
          minFreeSpace = "50GB";
        };
      };
    in
    {
      users.groups.buildkit = { };
      users.users.buildkit = {
        isSystemUser = true;
        group = "buildkit";
        home = "/var/lib/buildkit";
        # Above the auto-allocated ranges of normal users (from 100000).
        subUidRanges = [
          {
            startUid = 1000000;
            count = 65536;
          }
        ];
        subGidRanges = [
          {
            startGid = 1000000;
            count = 65536;
          }
        ];
      };

      sops.secrets.buildkit-server-key.sopsFile = ../../../secrets/hosts/daddy.yaml;

      systemd.services.buildkit = {
        description = "Rootless BuildKit daemon for CI";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        # newuidmap/newgidmap are setuid wrappers, so no NoNewPrivileges here.
        path = [
          "/run/wrappers"
          pkgs.rootlesskit
          pkgs.slirp4netns
          # rootlesskit sets up slirp4netns's tap device with nsenter and ip.
          pkgs.util-linux
          pkgs.iproute2
          pkgs.runc
          pkgs.git
        ];
        environment.XDG_RUNTIME_DIR = "/run/buildkit";
        serviceConfig = {
          User = "buildkit";
          Group = "buildkit";
          StateDirectory = "buildkit";
          RuntimeDirectory = "buildkit";
          LoadCredential = [ "server-key:${config.sops.secrets.buildkit-server-key.path}" ];
          # The port driver listens on the host and forwards into the
          # namespace; slirp4netns gives it outbound network only.
          ExecStart = lib.concatStringsSep " " [
            "${lib.getExe' pkgs.rootlesskit "rootlesskit"}"
            "--net=slirp4netns"
            "--disable-host-loopback"
            "--copy-up=/etc"
            "--state-dir=/run/buildkit/rootlesskit"
            "--port-driver=builtin"
            "--publish=0.0.0.0:${toString port}:${toString port}/tcp"
            "${lib.getExe' pkgs.buildkit "buildkitd"}"
            "--config=${settings}"
          ];
          Delegate = true;
          KillMode = "mixed";
          Restart = "on-failure";
          # Leaves room for kasha, Jellyfin and the nix-daemon's own builds.
          MemoryMax = "12G";
          CPUWeight = 20;
          IOWeight = 20;
        };
      };

      # The port is open to the k3s nodes only (pod traffic leaves masqueraded
      # to its node IP); the certificate check is the real gate.
      #
      # Build containers must not reach the LAN, the tailnet or daddy itself:
      # that would bypass the runner pods' NetworkPolicy. Their connections are
      # made by slirp4netns as the buildkit user, so an owner match covers
      # them; DNS to the router is the one exception. Replies to the nodes on
      # the published port pass as established.
      networking.firewall = {
        extraCommands = ''
          for ip in ${toString clients}; do
            iptables -A nixos-fw -p tcp -s "$ip" --dport ${toString port} -j nixos-fw-accept
          done

          ip46tables -N buildkit-egress 2>/dev/null || ip46tables -F buildkit-egress
          ip46tables -C OUTPUT -m owner --uid-owner buildkit -j buildkit-egress 2>/dev/null \
            || ip46tables -I OUTPUT -m owner --uid-owner buildkit -j buildkit-egress
          ip46tables -A buildkit-egress -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
          for proto in udp tcp; do
            iptables -A buildkit-egress -p "$proto" -d 192.168.0.1 --dport 53 -j RETURN
          done
          for net in 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16; do
            iptables -A buildkit-egress -d "$net" -j REJECT
          done
          for net in ::1/128 fc00::/7 fe80::/10; do
            ip6tables -A buildkit-egress -d "$net" -j REJECT
          done
        '';
        extraStopCommands = ''
          ip46tables -D OUTPUT -m owner --uid-owner buildkit -j buildkit-egress 2>/dev/null || true
          ip46tables -F buildkit-egress 2>/dev/null || true
          ip46tables -X buildkit-egress 2>/dev/null || true
        '';
      };
    };
}
