{ self, ... }:
{
  flake.modules.homeManager.scripts = _: {
    home.file.".local/bin" = {
      source = "${self}/assets/bin";
      recursive = true;
    };
  };
}
