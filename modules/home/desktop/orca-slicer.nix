_: {
  flake.modules.homeManager.orca-slicer =
    {
      lib,
      config,
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
        impermanence = lib.mkIf (config.znix.impermanence.enable or false) {
          home.persistence."/persist".directories = [ ".config/OrcaSlicer" ];
        };
      in
      lib.mkMerge [
        base
        impermanence
      ]
    );
}
