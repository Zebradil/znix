_: {
  flake.modules.nixos.docker =
    {
      config,
      lib,
      ...
    }:
    {
      options.znix.docker.enable = lib.mkEnableOption "Docker";

      config = lib.mkIf config.znix.docker.enable {
        virtualisation.docker.enable = true;
      };
    };
}
