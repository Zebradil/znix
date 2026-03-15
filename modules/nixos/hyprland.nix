{ ... }:
{
  flake.modules.nixos.hyprland =
    { pkgs, ... }:
    {
      nix.settings = {
        substituters = [ "https://hyprland.cachix.org" ];
        trusted-substituters = [ "https://hyprland.cachix.org" ];
        trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
      };

      programs.hyprland.enable = true;
      # Optional, hint electron apps to use wayland:
      environment.sessionVariables.NIXOS_OZONE_WL = "1";
      environment.systemPackages = [
        pkgs.kitty # required for the default Hyprland config
      ];
    };
}
