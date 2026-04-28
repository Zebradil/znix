let
  esc = builtins.fromJSON ''"\u001b"'';
  green = "${esc}[1;32m";
  reset = "${esc}[0m";
in
_: {
  flake.modules.homeManager.direnv =
    { lib, osConfig, ... }:
    let
      base = {
        programs.direnv = {
          enable = true;
          nix-direnv.enable = true;
          config.global = {
            hide_env_diff = true;
            load_dotenv = false;
            log_filter = "^(loading|unloading) ";
            log_format = "${green}direnv:${reset} %s";
          };
        };
      };
      impermanence = lib.mkIf osConfig.znix.impermanence.enable {
        home.persistence."/persist".directories = [ ".local/share/direnv" ];
      };
    in
    lib.mkMerge [
      base
      impermanence
    ];
}
