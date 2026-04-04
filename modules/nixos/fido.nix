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
        security.pam.services = {
          login.u2fAuth = true;
          sudo.u2fAuth = true;
          hyprlock.u2fAuth = true;
        };
      };
    };
}
