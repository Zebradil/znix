{ ... }:
{
  flake.modules.homeManager.ssh =
    { ... }:
    {
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        includes = [
          "~/.orbstack/ssh/config"
          "conf.d/*"
        ];
      };
    };
}
