{ ... }:
{
  flake.modules.homeManager.repo-dir =
    { config, lib, ... }:
    {
      options.znix.repoDir = lib.mkOption {
        type = lib.types.str;
        default = "${config.home.homeDirectory}/code/github.com/zebradil/znix";
        description = "Absolute path to the znix repository checkout";
      };
    };
}
