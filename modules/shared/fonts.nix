{ ... }:
let
  fontsModule =
    { pkgs, ... }:
    {
      fonts.packages = with pkgs; [
        iosevka-bin
        nerd-fonts.iosevka-term
      ];
    };
in
{
  flake.modules.nixos.fonts = fontsModule;
  flake.modules.darwin.fonts = fontsModule;
}
