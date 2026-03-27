_:
let
  nixosModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.znix.diff.enable = lib.mkEnableOption "rebuild diff summary";

      config = lib.mkIf config.znix.diff.enable {
        system.activationScripts.diff = {
          supportsDryActivation = true;
          text = ''
            if [ -e /run/current-system ]; then
              ${pkgs.nvd}/bin/nvd --nix-bin-dir=${pkgs.nix}/bin diff /run/current-system "$systemConfig"
            fi
          '';
        };
      };
    };

  darwinModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.znix.diff.enable = lib.mkEnableOption "rebuild diff summary";

      config = lib.mkIf config.znix.diff.enable {
        system.activationScripts.postActivation.text = ''
          if [ -e /run/current-system ]; then
            ${pkgs.nvd}/bin/nvd diff /run/current-system "$systemConfig"
          fi
        '';
      };
    };
in
{
  flake.modules.nixos.diff = nixosModule;
  flake.modules.darwin.diff = darwinModule;
}
