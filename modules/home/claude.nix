_: {
  flake.modules.homeManager.claude =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      base = {
        home.packages = with pkgs; [
          claude-code
          claude-monitor
        ];
      };
      impermanence = lib.mkIf osConfig.znix.impermanence.enable {
        home.persistence."/persist" = {
          directories = [ ".claude" ];
          files = [ ".claude.json" ];
        };
      };
    in
    lib.mkMerge [
      base
      impermanence
    ];
}
