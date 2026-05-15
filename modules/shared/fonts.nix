_:
let
  commonFonts =
    { pkgs, ... }:
    {
      fonts.packages = with pkgs; [
        nerd-fonts.iosevka-term
        noto-fonts-color-emoji
      ];
    };

  nixosFonts = {
    fonts.fontconfig.defaultFonts = {
      monospace = [
        "IosevkaTerm Nerd Font"
        "Noto Color Emoji"
      ];
      emoji = [ "Noto Color Emoji" ];
    };
  };
in
{
  flake.modules.nixos.fonts = {
    imports = [
      commonFonts
      nixosFonts
    ];
  };
  flake.modules.darwin.fonts = commonFonts;
}
