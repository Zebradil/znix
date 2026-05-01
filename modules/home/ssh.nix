_: {
  flake.modules.homeManager.ssh =
    {
      lib,
      osConfig,
      ...
    }:
    let
      base = {
        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;
          includes = [
            "~/.orbstack/ssh/config"
            "conf.d/*"
          ];
        };
      };
      impermanence = lib.mkIf osConfig.znix.impermanence.enable {
        home.persistence."/persist".files = [ ".ssh/known_hosts" ];
      };
    in
    lib.mkMerge [
      base
      impermanence
    ];
}
