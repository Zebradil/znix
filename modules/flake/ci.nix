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
  };
}
