{ inputs, ... }:
{
  flake.checks = {
    # Hosts with HomeManager need switching off useWritableLinks,
    # because there's no source repository in CI sandbox environment set correctly.

    # Standalone home entrypoints (`home-manager switch .#<key>`) build their
    # own pkgs, so their closures differ from the integrated home inside the
    # system toplevels above and must be built/pushed separately.

    x86_64-linux = {
      tuxedo-build =
        (inputs.self.nixosConfigurations.tuxedo.extendModules {
          modules = [ { home-manager.sharedModules = [ { znix.useWritableLinks = false; } ]; } ];
        }).config.system.build.toplevel;

      zebradil-tuxedo-home-build = inputs.self.homeConfigurations."zebradil@tuxedo".activationPackage;

      junior-build = inputs.self.nixosConfigurations.junior.config.system.build.toplevel;
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
