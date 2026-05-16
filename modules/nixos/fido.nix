_: {
  flake.modules.nixos.fido =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      fido-sound = pkgs.writeShellScript "fido-sound" ''
        if [ -n "$PAM_USER" ]; then
          USER_ID=$(id -u "$PAM_USER")
          CMD="env XDG_RUNTIME_DIR=/run/user/$USER_ID ${pkgs.pipewire}/bin/pw-play ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/message.oga"

          if [ -d "/run/user/$USER_ID" ]; then
            if [ "$(id -u)" -eq 0 ]; then
              USER_GID=$(id -g "$PAM_USER")
              ${pkgs.util-linux}/bin/setpriv --reuid="$USER_ID" --regid="$USER_GID" --init-groups $CMD >/dev/null 2>&1 &
            else
              sh -c "$CMD >/dev/null 2>&1 &"
            fi
          fi
        fi
      '';

      fidoSoundRule = {
        order = 10899;
        control = "optional";
        modulePath = "${pkgs.linux-pam}/lib/security/pam_exec.so";
        args = [
          "quiet"
          "${fido-sound}"
        ];
      };
    in
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
          login = {
            u2fAuth = true;
            rules.auth.fido_sound = fidoSoundRule;
          };
          sudo = {
            u2fAuth = true;
            rules.auth.fido_sound = fidoSoundRule;
          };
          hyprlock = {
            u2fAuth = true;
            rules.auth.fido_sound = fidoSoundRule;
          };
          polkit-1 = {
            u2fAuth = true;
            rules.auth.fido_sound = fidoSoundRule;
          };
        };
      };
    };
}
