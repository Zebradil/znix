_: {
  flake.modules.nixos.k3s-agent =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.znix.k3sAgent;
    in
    {
      options.znix.k3sAgent.enable = lib.mkEnableOption "k3s agent joining homelab cluster";

      config = lib.mkIf cfg.enable {
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
          role = "agent";
          package = pkgs.k3s_1_36;
          # TODO: pull this from the master config when it's checked into this nix config
          serverAddr = "https://192.168.0.100:6443";
          tokenFile = config.sops.secrets.k3s-token.path;
        };

        # k3s reads registries.yaml only at start. Restart when the encrypted
        # secrets file changes so password rotation and secret edits take effect
        # (structural edits to the template above are rare -> restart by hand).
        systemd.services.k3s.restartTriggers = [
          config.sops.secrets.oci-registry-password.sopsFile
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
