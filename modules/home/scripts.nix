{ self, ... }:
{
  flake.modules.homeManager.scripts =
    { config, ... }:
    {
      home.file."${config.home.homeDirectory}/.local/bin" = {
        source = "${self}/assets/bin";
        recursive = true;
      };
    };
}
