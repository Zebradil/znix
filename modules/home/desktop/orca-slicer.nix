_: {
  flake.modules.homeManager.orca-slicer =
    {
      lib,
      osConfig,
      pkgs,
      isDarwin,
      ...
    }:
    lib.mkIf (!isDarwin) (
      let
        base = {
          home.packages = with pkgs; [
            orca-slicer
          ];
        };
        impermanence = lib.mkIf (osConfig.znix.impermanence.enable or false) {
          home.persistence."/persist".directories = [ ".config/OrcaSlicer" ];
        };
      in
      lib.mkMerge [
        base
        impermanence
      ]
    );
}
