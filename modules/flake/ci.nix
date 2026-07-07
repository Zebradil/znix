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

    # Standalone home entrypoints (`home-manager switch .#<key>`) build their
    # own pkgs, so their closures differ from the integrated home inside the
    # system toplevels above and must be built/pushed separately. Named
    # `*-build` so the darwin one clears the CI attr-filter (`-build$`).
    aarch64-darwin.glashevich-trv4250-home-build =
      inputs.self.homeConfigurations."glashevich@trv4250".activationPackage;
    x86_64-linux.zebradil-tuxedo-home-build =
      inputs.self.homeConfigurations."zebradil@tuxedo".activationPackage;
  };
}
