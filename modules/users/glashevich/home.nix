{ self, ... }:
let
  # GitHub PRs authored & merged since the last standup. {{since}} is replaced
  # (as YYYY-MM-DD) by the /standup skill.
  ghPrsSource = {
    name = "GitHub PRs";
    cmd = "gh search prs --author=@me --merged --updated '>={{since}}' --json title,url,repository --jq '.[] | \"- \\(.title) — \\(.repository.nameWithOwner)\"'";
  };

  mkCompanyProfile =
    { configDir, command }:
    {
      enable = true;
      caveman = true;
      ponytail = true;
      worklog = true;
      worklogName = "trv"; # both company profiles share one worklog
      worklogSources = [ ghPrsSource ];
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
        worklog.enable = true;

        profiles = {
          personal = self.lib.claude.mkPersonalProfile { } // {
            worklog = true;
            worklogSources = [ ghPrsSource ];
          };

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
