{ self, ... }:
{
  # Standalone-home profile for zebradil@tuxedo. Consumed two ways:
  #   - integrated: imported into home-manager.users.zebradil (see default.nix)
  #   - standalone: imported by homeConfigurations."zebradil@tuxedo" (Phase 3)
  # Registered under `generic` (NOT homeManager): the integrated
  # `attrValues homeManager` sweep only reads the homeManager class, so a
  # generic module never leaks into another user's config. `generic` is the one
  # class flake-parts leaves unstamped (no `_class`), so it still imports
  # cleanly into a homeManager evaluation — a bespoke class would be rejected
  # for a class mismatch.
  #
  # ponytail: user↔host is 1:1 today; split a host overlay when a user spans hosts.
  flake.modules.generic.home-zebradil =
    { lib, config, ... }:
    {
      imports = [ ./_home.nix ];

      home = {
        username = "zebradil";
        homeDirectory = "/home/zebradil";
        stateVersion = "26.05";

        persistence."/persist" = lib.mkIf config.znix.impermanence.enable {
          directories = [
            ".local/share/nix" # trusted settings and repl history
            "code" # code projects

            "Documents"
            "Downloads"
            "Pictures"
            "Videos"
          ];
        };
      };

      znix.impermanence.enable = true;

      znix.claude = {
        caveman.enable = true;
        ponytail.enable = true;
        profiles.personal = self.lib.claude.mkPersonalProfile { };
      };
    };
}
