_: {
  flake.modules.nixos.boot =
    { config, lib, ... }:
    {
      options.znix.boot.enable = lib.mkEnableOption "system boot configuration";

      config = lib.mkIf config.znix.boot.enable {
        boot = {
          loader = {
            systemd-boot = {
              enable = true;
              consoleMode = "max";
            };
            efi.canTouchEfiVariables = true;
          };
          initrd.systemd.enable = true;
        };
      };
    };
}
