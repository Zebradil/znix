_: {
  flake.modules.homeManager.brave =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      base = {
        home.packages = with pkgs; [
          brave
        ];
      };
      impermanence = lib.mkIf config.znix.impermanence.enable {
        # home.persistence."/persist".directories = [ ".config/brave" ];
      };
    in
    lib.mkMerge [
      base
      impermanence
    ];
}
