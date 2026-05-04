{ ... }:
{
  flake.modules.nixos.tailscale =
    {
      config,
      lib,
      ...
    }:
    let
      hasOptinPersistence = config.environment.persistence ? "/persist";
    in
    {
      options.znix.tailscale.enable = lib.mkEnableOption "Tailscale";

      config = lib.mkIf config.znix.tailscale.enable {
        services.tailscale.enable = true;

        environment.persistence."/persist".directories = lib.mkIf hasOptinPersistence [
          "/var/lib/tailscale"
        ];
      };
    };

  flake.modules.homeManager.tailscale =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.tailscale ];
    };
}
