{
  config,
  lib,
  pkgs,
  ...
}:
let
  wallpaperDir = "${config.home.homeDirectory}/Pictures/Wallpapers";
  currentWallpaper = "${wallpaperDir}/current";
  setWallpaper = pkgs.writeShellApplication {
    name = "set-wallpaper";
    runtimeInputs = with pkgs; [
      coreutils
      hyprland
      libnotify
    ];
    text = ''
      set -eu

      if [ "$#" -ne 1 ]; then
        printf 'Usage: set-wallpaper /path/to/image\n' >&2
        exit 1
      fi

      wallpaper="$1"
      wallpaper_dir="${wallpaperDir}"
      current_wallpaper="${currentWallpaper}"

      if [ ! -f "$wallpaper" ]; then
        printf 'Wallpaper not found: %s\n' "$wallpaper" >&2
        exit 1
      fi

      mkdir -p "$wallpaper_dir"
      ln -sfn "$wallpaper" "$current_wallpaper"

      if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ -n "''${XDG_RUNTIME_DIR:-}" ]; then
        hyprctl hyprpaper unload all >/dev/null
        hyprctl hyprpaper preload "$current_wallpaper" >/dev/null
        hyprctl hyprpaper wallpaper ",$current_wallpaper" >/dev/null
      fi

      notify-send "Wallpaper updated" "$wallpaper"
    '';
  };
in
{
  home.packages = [ setWallpaper ];

  home.activation.hyprpaperDefaultWallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    wallpaper_dir="${wallpaperDir}"
    current_wallpaper="${currentWallpaper}"
    default_wallpaper="${pkgs.nixos-artwork.wallpapers.binary-black.gnomeFilePath}"

    mkdir -p "$wallpaper_dir"

    if [ ! -e "$current_wallpaper" ]; then
      ln -sfn "$default_wallpaper" "$current_wallpaper"
    fi
  '';

  services.hyprpaper = {
    enable = true;
    settings = {
      preload = [ currentWallpaper ];
      wallpaper = [
        {
          monitor = "";
          path = currentWallpaper;
        }
      ];
    };
  };
}
