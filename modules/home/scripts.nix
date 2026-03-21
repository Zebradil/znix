{ self, ... }:
{
  flake.modules.homeManager.scripts =
    { config, ... }:
    {
      home.file.".local/bin" = {
        source = "${self}/assets/bin";
        recursive = true;
      };
    };
}
