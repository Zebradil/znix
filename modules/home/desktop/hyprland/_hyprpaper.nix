{ pkgs, ... }:
let
  wallpaper = "${pkgs.nixos-artwork.wallpapers.nineish}/share/backgrounds/nixos/nix-wallpaper-nineish.png";
in
{
  services.hyprpaper = {
    enable = true;
    settings = {
      preload = [ wallpaper ];
      wallpaper = [
        {
          monitor = "";
          path = wallpaper;
        }
      ];
    };
  };
}
