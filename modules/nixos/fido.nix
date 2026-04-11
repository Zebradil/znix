_: {
  flake.modules.nixos.fido =
    {
      config,
      lib,
      ...
    }:
    {
      options.znix.fido.enable = lib.mkEnableOption "FIDO U2F/YubiKey PAM";

      config = lib.mkIf config.znix.fido.enable {
        security.pam.u2f.settings.cue = true;
        # WORKAROUND: polkit 127's polkit-agent-helper@.service ships with
        # PrivateDevices=yes, which blocks pam_u2f from accessing /dev/hidraw*.
        # Upstream issue: https://github.com/polkit-org/polkit/issues/622
        # Arch Linux ships the same override in their pam-u2f package.
        # Remove this block when polkit ships a native fix (check issue #622).
        systemd.services."polkit-agent-helper@".serviceConfig = {
          PrivateDevices = lib.mkForce false;
          DeviceAllow = [
            "/dev/null rw"
            "/dev/urandom r"
            "char-hidraw rw"
          ];
          ProtectHome = "read-only";
        };
        security.pam.services = {
          login.u2fAuth = true;
          sudo.u2fAuth = true;
          hyprlock.u2fAuth = true;
          polkit-1.u2fAuth = true;
        };
      };
    };
}
