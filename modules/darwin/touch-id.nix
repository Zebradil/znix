_: {
  flake.modules.darwin.touch-id = _: {
    security.pam.services.sudo_local.touchIdAuth = true;
  };
}
