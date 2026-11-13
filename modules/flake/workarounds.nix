# znix runs the framework it exports; entries live in ./workarounds/.
{
  imports = [ ./_workarounds ];
  flake.flakeModules.workarounds = ./_workarounds;
}
