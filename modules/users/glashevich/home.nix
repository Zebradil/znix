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
  # config (server, login) comes from the znix.jira module. The JQL must open
  # with `project IS NOT EMPTY`: jira-cli AND-prepends `project="<config key>"`
  # to every query, and the key is empty here, so an unguarded JQL matches
  # nothing at all.
  jiraSource = {
    name = "Jira";
    instruction = "Assigned tickets you moved this period — can back the topics above.";
    cmd = ''JIRA_API_TOKEN=$(op read 'op://Employee/Jira API token/credential') jira issue list --jql 'project IS NOT EMPTY AND assignee = currentUser() AND updated >= "{{since}}"' --plain --no-headers --no-truncate --columns KEY,STATUS,SUMMARY'';
  };

  # opencode keeps its own durable session history, so it needs no Stop hook —
  # the standup window is just a query against its SQLite store. `parent_id is
  # null` drops subagent sessions, the message floor drops throwaways, and
  # -readonly makes a renamed db (the filename tracks the release channel) fail
  # loudly instead of silently reporting zero sessions. `dirCmp` splits work
  # from personal: "like" for the trv worklog, "not like" for the personal one.
  mkOpencodeSource = dirCmp: {
    name = "opencode sessions";
    instruction = "Work done in opencode rather than Claude. May overlap the worklog or a PR above — merge, don't double-count.";
    cmd = ''sqlite3 -readonly ~/.local/share/opencode/opencode-stable.db "select '- ' || title || ' — ' || directory from session where parent_id is null and time_created >= strftime('%s','{{since}}') * 1000 and directory ${dirCmp} '%/github.com/trivago/%' and (select count(*) from message where message.session_id = session.id) > 2 order by time_created;"'';
  };

  mkCompanyProfile =
    { configDir, command }:
    {
      enable = true;
      caveman = true;
      ponytail = true;
      worklog = true;
      worklogName = "trv"; # both company profiles share one worklog
      worklogSources = mkGithubSources "org:trivago" ++ [
        jiraSource
        (mkOpencodeSource "like")
      ];
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

      znix = {
        aiBudget.enable = true;
        kube.homelab.enable = true;
        jira = {
          enable = true;
          server = "https://trivago.atlassian.net";
          login = "german.lashevich@trivago.com";
        };
        cursor.enable = true;
        claude = {
          caveman.enable = true;
          ponytail.enable = true;
          worklog.enable = true;

          profiles = {
            personal = self.lib.claude.mkPersonalProfile { } // {
              worklog = true;
              worklogSources = mkGithubSources "-org:trivago" ++ [ (mkOpencodeSource "not like") ];
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
    };
}
