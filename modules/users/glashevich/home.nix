{ self, ... }:
let
  # Standup GitHub sources for one org scope. `orgFilter` is a gh search
  # qualifier passed after `--` (so gh's parser treats "-org:trivago" as a
  # query token, not a flag): "org:trivago" for work, "-org:trivago" for
  # personal. {{since}} → last-standup date (YYYY-MM-DD), substituted by the
  # /standup skill. `--limit 1000` on the bot count so a Renovate flood isn't
  # silently truncated to gh's default 30.
  mkGithubSources = orgFilter: [
    {
      name = "PRs implemented";
      instruction = "Topics you built. Merge related PRs and commits across repos into single topics.";
      cmd = ''gh search prs --author=@me --updated '>={{since}}' --limit 200 --json title,repository,state --jq '.[] | "- \(.title) — \(.repository.nameWithOwner) [\(.state)]"' -- "${orgFilter}"'';
    }
    {
      name = "PRs reviewed";
      instruction = "Review work — keep separate from topics you implemented (someone else did the job).";
      cmd = ''gh search prs --reviewed-by=@me --updated '>={{since}}' --limit 200 --json title,repository,author --jq '[.[] | select(.author.type != "Bot")][] | "- \(.title) — \(.repository.nameWithOwner)"' -- "${orgFilter}"'';
    }
    {
      name = "Automated PRs";
      instruction = "Already an aggregate count — report the numbers as-is, do NOT enumerate individual PRs.";
      cmd = ''gh search prs --reviewed-by=@me --updated '>={{since}}' --limit 1000 --json repository,author --jq '[.[] | select(.author.type == "Bot")] as $b | "\($b|length) automated PRs across \([$b[].repository.nameWithOwner]|unique|length) repos", ($b | group_by(.repository.nameWithOwner)[] | "- \(.[0].repository.nameWithOwner): \(length)")' -- "${orgFilter}"'';
    }
    {
      name = "Commits";
      instruction = "Direct-push work. Dedup against the PRs above — a commit squashed into a listed PR is the same topic.";
      cmd = ''gh search commits --author=@me --committer-date '>={{since}}' --limit 200 --json repository,commit --jq '.[] | "- \(.commit.message | split("\n")[0]) — \(.repository.fullName)"' -- "${orgFilter}"'';
    }
  ];

  # Company-only. Token pulled at call time via op read (never on disk); jira-cli
  # config (server, login) comes from the znix.jira module.
  jiraSource = {
    name = "Jira";
    instruction = "Assigned tickets you moved this period — can back the topics above.";
    cmd = ''JIRA_API_TOKEN=$(op read 'op://Employee/Jira API token/credential') jira issue list --jql 'assignee = currentUser() AND updated >= "{{since}}"' --plain --no-headers --no-truncate --columns KEY,STATUS,SUMMARY'';
  };

  mkCompanyProfile =
    { configDir, command }:
    {
      enable = true;
      caveman = true;
      ponytail = true;
      worklog = true;
      worklogName = "trv"; # both company profiles share one worklog
      worklogSources = mkGithubSources "org:trivago" ++ [ jiraSource ];
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

      znix.jira = {
        enable = true;
        server = "https://trivago.atlassian.net";
        login = "german.lashevich@trivago.com";
      };

      znix.claude = {
        caveman.enable = true;
        ponytail.enable = true;
        worklog.enable = true;

        profiles = {
          personal = self.lib.claude.mkPersonalProfile { } // {
            worklog = true;
            worklogSources = mkGithubSources "-org:trivago";
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
