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

  nixosFonts =
    { pkgs, ... }:
    {
      fonts.fontconfig.defaultFonts = {
        monospace = [
          "IosevkaTerm Nerd Font"
          "Noto Color Emoji"
        ];
        emoji = [ "Noto Color Emoji" ];
      };

      environment.systemPackages = [
        pkgs.font-manager
      ];
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
