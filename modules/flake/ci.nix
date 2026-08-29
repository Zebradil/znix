{ inputs, ... }:
{
  flake.checks = {
    # Hosts with HomeManager need switching off useWritableLinks,
    # because there's no source repository in CI sandbox environment set correctly.

    # Standalone home entrypoints (`home-manager switch .#<key>`) build their
    # own pkgs, so their closures differ from the integrated home inside the
    # system toplevels above and must be built/pushed separately.

    aarch64-linux.toddler-build = inputs.self.nixosConfigurations.toddler.config.system.build.toplevel;

    aarch64-darwin = {
      trv4250-build =
        (inputs.self.darwinConfigurations.trv4250.extendModules {
          modules = [ { home-manager.sharedModules = [ { znix.useWritableLinks = false; } ]; } ];
        }).config.system.build.toplevel;

      glashevich-trv4250-home-build =
        inputs.self.homeConfigurations."glashevich@trv4250".activationPackage;
    };

    x86_64-linux = {
      tuxedo-build =
        (inputs.self.nixosConfigurations.tuxedo.extendModules {
          modules = [ { home-manager.sharedModules = [ { znix.useWritableLinks = false; } ]; } ];
        }).config.system.build.toplevel;

      zebradil-tuxedo-home-build = inputs.self.homeConfigurations."zebradil@tuxedo".activationPackage;

      junior-build = inputs.self.nixosConfigurations.junior.config.system.build.toplevel;

      # toddler's blebridge is an aarch64 binary cross-built by an x86_64
      # builder, so the aarch64 runner cannot build it (build-set.sh skips it).
      # Building it here keeps the cache complete for toddler's closure.
      blebridge-arm64 = inputs.blebridge.packages.x86_64-linux.blebridge-arm64;
    }
    // builtins.listToAttrs (
      builtins.genList (
        i:
        let
          idx = toString (i + 1);
        in
        {
          name = "d${idx}-build";
          value = inputs.self.nixosConfigurations."d${idx}".config.system.build.toplevel;
        }
      ) 3
    );
  };
}
