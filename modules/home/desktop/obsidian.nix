_: {
  flake.modules.homeManager.obsidian =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      base = {
        home.packages = with pkgs; [
          obsidian
        ];
      };
      impermanence = lib.mkIf config.znix.impermanence.enable {
        home.persistence."/persist".directories = [ ".config/obsidian" ];
      };
    in
    lib.mkMerge [
      base
      impermanence
    ];
}
