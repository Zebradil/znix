{ ... }:
{
  flake.modules.nixos.gdm =
    { ... }:
    {
      services.displayManager = {
        enable = true;
        gdm.enable = true;
      };
    };
}
