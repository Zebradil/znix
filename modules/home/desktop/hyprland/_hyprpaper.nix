{ pkgs, ... }:
let
  wallpaper = pkgs.nixos-artwork.wallpapers.binary-black.gnomeFilePath;
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
