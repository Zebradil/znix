let
  esc = builtins.fromJSON ''"\u001b"'';
  green = "${esc}[1;32m";
  reset = "${esc}[0m";
in
_: {
  flake.modules.homeManager.direnv = _: {
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
}
