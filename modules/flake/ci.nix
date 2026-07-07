{ inputs, ... }:
{
  flake.checks = {
    aarch64-darwin.trv4250-build =
      (inputs.self.darwinConfigurations.trv4250.extendModules {
        modules = [ { home-manager.sharedModules = [ { znix.useWritableLinks = false; } ]; } ];
      }).config.system.build.toplevel;
    x86_64-linux.tuxedo-build =
      (inputs.self.nixosConfigurations.tuxedo.extendModules {
        modules = [ { home-manager.sharedModules = [ { znix.useWritableLinks = false; } ]; } ];
      }).config.system.build.toplevel;
    # toddler has no home-manager (suok is a bare admin user), so no
    # useWritableLinks override is needed — a plain toplevel reference.
    aarch64-linux.toddler-build =
      inputs.self.nixosConfigurations.toddler.config.system.build.toplevel;
  };
}
