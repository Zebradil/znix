_: {
  flake.modules.homeManager.brave =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      base = {
        home.packages = with pkgs; [
          brave
        ];
      };
      impermanence = lib.mkIf osConfig.znix.impermanence.enable {
        # home.persistence."/persist".directories = [ ".config/brave" ];
      };
    in
    lib.mkMerge [
      base
      impermanence
    ];
}
