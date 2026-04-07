_: {
  flake.modules.nixos.hardware-monitoring =
    { config, lib, ... }:
    {
      options.znix.hardware-monitoring.enable = lib.mkEnableOption "hardware monitoring access (powercap, etc.)";

      config = lib.mkIf config.znix.hardware-monitoring.enable {
        systemd.tmpfiles.rules = [
          "z /sys/class/powercap/intel-rapl:0/energy_uj 0440 root wheel - -"
        ];
      };
    };
}
