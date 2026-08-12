_: {
  flake.modules.homeManager.yazi =
    { pkgs, ... }:
    {
      programs.yazi = {
        enable = true;
        enableZshIntegration = true;
        enableNushellIntegration = true;

        # Preview backends yazi shells out to: video thumbnails, PDF first-page
        # render, archive listing. Missing binary = blank preview pane, so they
        # are scoped to yazi's own PATH rather than added to home.packages.
        extraPackages = with pkgs; [
          ffmpeg-headless
          poppler-utils
          _7zz
        ];
      };
    };
}
