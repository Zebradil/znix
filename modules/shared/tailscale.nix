{ ... }:
{
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
      };

      # tailscaled state lives in /var/lib/tailscale; on impermanence hosts it is
      # persisted from the impermanence manifest (guarded by services.tailscale.enable),
      # not here — this module is imported by non-impermanence hosts too, and
      # defining environment.persistence there errors even under mkIf.
      config = lib.mkIf cfg.enable {
        services.tailscale = {
          enable = true;
          authKeyFile = cfg.authKeyFile;
          extraUpFlags = lib.mkIf (cfg.advertiseTags != [ ]) [
            "--advertise-tags=${lib.concatStringsSep "," cfg.advertiseTags}"
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
