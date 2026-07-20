_: {
  # Shared plumbing for every k3s node in the homelab cluster (agents + the
  # `junior` server). Both roles are also workers, so they share the same
  # datastore token, Harbor pull credentials, iSCSI host wiring and worker
  # firewall. Role-specific bits (agent `serverAddr`, server flags) live in the
  # consuming module.
  flake.modules.nixos.k3s-node =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.znix.k3sNode;
    in
    {
      options.znix.k3sNode = {
        enable = lib.mkEnableOption "k3s node plumbing shared by agents and the server";

        # No defaults: a k3s node must declare both, else /etc/hosts below errors
        # at eval. Self-referential names every node resolves locally — resolved
        # is off fleet-wide, so MagicDNS/router DNS can't serve these.
        selfLan = lib.mkOption {
          type = lib.types.str;
          example = "192.168.0.100";
          description = "This node's LAN IPv4, published as `node.k8s.lan` in /etc/hosts.";
        };
        selfVpn = lib.mkOption {
          type = lib.types.str;
          example = "100.85.146.64";
          description = "This node's tailscale IPv4, published as `node.k8s.vpn` in /etc/hosts.";
        };
      };

      config = lib.mkIf cfg.enable {
        # Stable self-names for the local node over LAN and tailscale.
        networking.hosts = {
          ${cfg.selfLan} = [ "node.k8s.lan" ];
          ${cfg.selfVpn} = [ "node.k8s.vpn" ];
        };

        sops = {
          secrets = {
            k3s-token.sopsFile = ../../secrets/hosts/k3s.yaml;
            oci-registry-password.sopsFile = ../../secrets/hosts/k3s.yaml;
          };
          templates."registries.yaml" = {
            path = "/etc/rancher/k3s/registries.yaml";
            mode = "0600";
            content = ''
              mirrors:
                oci.zebradil.dev:
                  endpoint:
                    - https://oci.zebradil.dev
              configs:
                oci.zebradil.dev:
                  auth:
                    username: "robot$homelab-puller"
                    password: "${config.sops.placeholder.oci-registry-password}"
            '';
          };
        };

        services.k3s = {
          enable = true;
          package = pkgs.k3s_1_36;
          tokenFile = config.sops.secrets.k3s-token.path;
        };

        # k3s reads registries.yaml only at start. Restart when the encrypted
        # secrets file changes so password rotation and secret edits take effect
        # (structural edits to the template above are rare -> restart by hand).
        systemd.services.k3s.restartTriggers = [
          config.sops.secrets.oci-registry-password.sopsFile
        ];

        # synology-csi's node plugin needs iscsiadm on the host.
        services.openiscsi = {
          enable = true;
          name = "iqn.2005-03.org.open-iscsi:${config.networking.hostName}";
        };

        # The plugin execs `env iscsiadm` with the container's PATH
        # (/usr/sbin:/sbin:...), which misses NixOS's /run/current-system/sw/bin.
        # Bridge the binary onto /usr/bin — on PATH and the one FHS bin dir NixOS
        # populates. Without this, iscsiadm is installed but `env` can't find it.
        systemd.tmpfiles.rules = [
          "L+ /usr/bin/iscsiadm - - - - /run/current-system/sw/sbin/iscsiadm"
        ];

        # Open kubelet (server -> agent), metrics and flannel VXLAN, and trust the CNI/overlay interfaces.
        networking.firewall = {
          allowedTCPPorts = [
            10250
            19100
            9100
          ];
          allowedUDPPorts = [ 8472 ];
          trustedInterfaces = [
            "flannel.1"
            "cni0"
          ];
        };
      };
    };
}
