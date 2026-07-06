{ self, ... }:
let
  mkCompanyProfile =
    { configDir, command }:
    {
      enable = true;
      caveman = true;
      ponytail = true;
      inherit configDir command;
    };
in
{
  # Home profile for glashevich@trv4250. Consumed by
  # homeConfigurations."glashevich@trv4250" (mkHomeManager).
  # `generic` class, not homeManager — see zebradil/home.nix for why.
  # Darwin has no impermanence, so znix.impermanence.enable stays at its default.
  #
  # ponytail: user↔host is 1:1 today; split a host overlay when a user spans hosts.
  flake.modules.generic.home-glashevich =
    { ... }:
    {
      imports = [ ./_home.nix ];

      home = {
        username = "glashevich";
        homeDirectory = "/Users/glashevich";
        stateVersion = "26.05";
      };

      znix.claude = {
        caveman.enable = true;
        ponytail.enable = true;

        profiles = {
          personal = self.lib.claude.mkPersonalProfile { };

          company = mkCompanyProfile {
            configDir = ".config/trv-claude";
            command = "trv-claude";
          };

          company-key =
            (mkCompanyProfile {
              configDir = ".config/trv-claude-key";
              command = "trv-claude-key";
            })
            // {
              runtimeEnv.ANTHROPIC_API_KEY = "op read 'op://Employee/Anthropic API key/credential'";
            };
        };
      };
    };
}
