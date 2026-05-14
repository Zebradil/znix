_:
let
  fontsModule =
    { pkgs, ... }:
    {
      fonts.packages = with pkgs; [
        nerd-fonts.iosevka-term
        noto-fonts-color-emoji
      ];
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
  flake.modules.nixos.fonts = fontsModule;
  flake.modules.darwin.fonts = fontsModule;
}
