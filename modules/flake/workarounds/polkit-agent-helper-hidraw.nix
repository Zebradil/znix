_: {
  workarounds.polkit-agent-helper-hidraw = {
    systems = [ "x86_64-linux" ];
    reason = "polkit's polkit-agent-helper@.service ships PrivateDevices=yes, so pam_u2f cannot reach /dev/hidraw* (https://github.com/polkit-org/polkit/issues/622).";
    # Arch Linux ships the same override in its pam-u2f package.
    module.nixos =
      { config, lib, ... }:
      {
        # Hosts without the fido module have no such option.
        config = lib.mkIf (config.znix.fido.enable or false) {
          systemd.services."polkit-agent-helper@".serviceConfig = {
            PrivateDevices = lib.mkForce false;
            DeviceAllow = [
              "/dev/null rw"
              "/dev/urandom r"
              "char-hidraw rw"
            ];
            ProtectHome = "read-only";
          };
        };
      };
    fixed =
      pkgs:
      pkgs.runCommand "polkit-agent-helper-allows-hidraw" { } ''
        unit=${pkgs.polkit.out}/lib/systemd/system/polkit-agent-helper@.service
        if grep -q '^PrivateDevices=yes' "$unit" && ! grep -q 'char-hidraw' "$unit"; then
          echo "$unit still hides /dev/hidraw*" >&2
          exit 1
        fi
        touch $out
      '';
  };
}
