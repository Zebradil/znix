{ ... }:
{
  flake.modules.darwin.touch-id =
    { ... }:
    {
      security.pam.services.sudo_local.touchIdAuth = true;
    };
}
