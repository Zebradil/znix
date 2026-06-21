---
description: Triage every open dependency-update PR and route each to the cheap (green) or capable (red) agent.
model: haiku
---

Process every open dependency-update pull request in this repository. Two bots open them here:
`app/renovate` (GitHub Actions bumps) and `app/zebradil` (flake.lock updates). Cover both.

1. List them, merging both authors:
   `gh pr list --author "app/renovate" --state open --json number,title,headRefName`
   `gh pr list --author "app/zebradil" --state open --json number,title,headRefName`

2. For EACH PR, cheaply determine CI status with `gh pr checks <number>`:
   - All checks passed -> dispatch the `renovate-green` subagent with that PR number.
   - Any check failed -> dispatch the `renovate-red` subagent with that PR number.
   - Checks still running/pending -> skip for now and note it; do not guess.

3. Dispatch green PRs first and in parallel where possible — they are fast and independent. Dispatch red PRs as
   separate subagents; each creates its own git worktree. Note: subagents queue rather than all running at once.

4. When all subagents finish, print a summary table: PR number | title | route (green/red/skipped) | outcome.

Do NOT read PR diffs yourself or reason about dependency complexity in this session — keep your own work to listing and
the green/red check so the cheap path stays cheap. The model choice is delegated to the agents.
