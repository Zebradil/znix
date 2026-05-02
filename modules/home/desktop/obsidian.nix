_: {
  flake.modules.homeManager.obsidian =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      base = {
        home.packages = with pkgs; [
          obsidian
        ];
      };
      impermanence = lib.mkIf osConfig.znix.impermanence.enable {
        home.persistence."/persist".directories = [ ".config/obsidian" ];
      };
    in
    lib.mkMerge [
      base
      impermanence
    ];
}
