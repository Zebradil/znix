_: {
  flake.modules.nixos.k3s-agent =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.znix.k3sAgent;
    in
    {
      options.znix.k3sAgent.enable = lib.mkEnableOption "k3s agent joining homelab cluster";

      config = lib.mkIf cfg.enable {
        # All shared worker plumbing (token, registries, iSCSI, firewall) lives
        # in k3s-node; the agent adds only its role and the server it joins.
        znix.k3sNode.enable = true;

        services.k3s = {
          role = "agent";
          serverAddr = "https://192.168.0.100:6443";
        };
      };
    };
}
