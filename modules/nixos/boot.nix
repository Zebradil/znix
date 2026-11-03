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
              # Keeps the 512M ESP from filling with one kernel+initrd per generation.
              configurationLimit = 10;
            };
            efi.canTouchEfiVariables = true;
          };
        };
      };
    };
}
