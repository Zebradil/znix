_: {
  flake.modules.nixos.tailscale =
    {
      config,
      lib,
      ...
    }:
    {
      options.znix.tailscale.enable = lib.mkEnableOption "Tailscale";

      config = lib.mkIf config.znix.tailscale.enable {
        services.tailscale.enable = true;

        environment.persistence."/persist".directories = [ "/var/lib/tailscale" ];
      };
    };
}
