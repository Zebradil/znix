_: {
  flake.modules.homeManager.image-viewers =
    {
      lib,
      pkgs,
      isDarwin,
      ...
    }:
    # Wayland-only viewers: guarded in-module rather than via the darwin
    # excludeModules denylist, same as hyprland.
    lib.optionalAttrs (!isDarwin) {
      home.packages = with pkgs; [
        swayimg
        loupe # trialling alongside swayimg; drop once one of them wins
      ];

      # swayimg and loupe both claim the whole image/* set, so without an
      # explicit default xdg-open picks by desktop-database ordering. The
      # store-symlinked mimeapps.list also survives impermanence for free.
      xdg.mimeApps = {
        enable = true;
        defaultApplications = lib.genAttrs [
          "image/jpeg"
          "image/png"
          "image/webp"
          "image/gif"
          "image/avif"
          "image/heif"
          "image/tiff"
          "image/bmp"
        ] (_: "swayimg.desktop");
      };
    };
}
