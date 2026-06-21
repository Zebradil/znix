---
description: Triage every open dependency-update PR and route each to the cheap (green) or capable (red) agent.
model: haiku
allowed-tools: Bash(gh pr list:*), Bash(gh pr checks:*), Bash(gh pr view:*)
---

Process every open dependency-update pull request in this repository. Two bots open them here:
`app/renovate` (GitHub Actions bumps) and `app/zebradil` (flake.lock updates). Cover both.

1. List them, merging both authors:
   `gh pr list --author "app/renovate" --state open --json number,title,headRefName`
   `gh pr list --author "app/zebradil" --state open --json number,title,headRefName`

2. For EACH PR, determine route using two cheap checks:

   a. Merge status: `gh pr view <number> --json mergeable -q .mergeable`
      - `CONFLICTING` → red (needs rebase/fix regardless of CI)
      - `UNKNOWN` → skip (GitHub hasn't computed it yet)
      - `MERGEABLE` → proceed to CI check

   b. CI status (only if MERGEABLE): `gh pr checks <number>`
      - All checks passed → green
      - Any check failed → red
      - Any check pending/running → skip

3. Dispatch green PRs first and in parallel where possible — they are fast and independent. Dispatch red PRs as
   separate subagents; each creates its own git worktree. Note: subagents queue rather than all running at once.

4. When all subagents finish, print a summary table: PR number | title | route (green/red/skipped) | outcome.

Do NOT read PR diffs yourself or reason about dependency complexity in this session — keep your own work to listing and
the green/red check so the cheap path stays cheap. The model choice is delegated to the agents.
