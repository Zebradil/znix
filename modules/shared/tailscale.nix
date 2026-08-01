_: {
  flake.modules.nixos.tailscale =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.znix.tailscale;
    in
    {
      options.znix.tailscale = {
        enable = lib.mkEnableOption "Tailscale";

        authKeyFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = ''
            Path to a file holding a Tailscale auth key or OAuth client secret.
            When set, the node authenticates unattended on first boot. Point it at
            a sops-rendered secret (see the k3s hosts).
          '';
        };

        advertiseTags = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "tag:k3s" ];
          description = ''
            Tags advertised at auth time (`--advertise-tags`). Required when
            authenticating with an OAuth client secret; tagged nodes also never
            key-expire, which is what makes headless hosts set-and-forget.
          '';
        };

        advertiseRoutes = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "192.168.0.0/24" ];
          description = ''
            CIDRs this node advertises as a subnet router. Each route must also
            be approved once in the Tailscale admin console (or covered by an
            `autoApprovers` ACL rule) before it carries traffic.

            Advertise the narrowest prefix that covers what you need: a tailnet
            client that roams onto a foreign LAN inside an over-broad prefix
            will route that LAN over the tunnel instead of locally.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        services.tailscale = {
          enable = true;
          inherit (cfg) authKeyFile;

          # Sets net.ipv4/ipv6 forwarding. Without it the node advertises routes
          # but silently drops every forwarded packet.
          useRoutingFeatures = lib.mkIf (cfg.advertiseRoutes != [ ]) "server";

          # Tags are fixed at registration; `tailscale set` cannot change them.
          extraUpFlags = lib.mkIf (cfg.advertiseTags != [ ]) [
            "--advertise-tags=${lib.concatStringsSep "," cfg.advertiseTags}"
          ];

          # Routes go through `tailscale set`, not `up`: extraUpFlags only fire
          # while the node is unauthenticated, so an already-registered host
          # would never pick up a route change. Emitted unconditionally so
          # clearing the list retracts the routes instead of leaving them
          # stranded in tailscaled's state.
          extraSetFlags = [
            "--advertise-routes=${lib.concatStringsSep "," cfg.advertiseRoutes}"
          ];
        };
      };
    };

  flake.modules.homeManager.tailscale =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.tailscale ];
    };
}
