---
description: Triage every open dependency-update bot PR, auto-merge the green ones, and route red ones to the fix agent.
model: haiku
allowed-tools: Bash(gh-renovate-triage:*), Task
---

Run the triage script, then hand every red PR to the fix agent.

1. `gh-renovate-triage`

   It lists every open bot PR (author `is_bot`, filtered to an allowlist), classifies each, and **already
   approves + merges the green ones itself** (strategy: `merge --auto`, falling back to a plain squash then an
   admin merge, surfacing any raw `gh` error). It prints four sections: GREEN (with per-PR outcome), RED, SKIPPED,
   and UNKNOWN BOTS. Do NOT re-check or re-merge greens — the script owns that path.

2. For each PR number under **RED**, dispatch a `renovate-red` subagent (Task tool), passing the PR number. They
   run in isolated worktrees and queue rather than all running at once.

3. When the subagents finish, print one summary table: PR number | route (green/red/skipped) | outcome — combining
   the script's GREEN/SKIPPED lines with each red agent's reported result. Surface the UNKNOWN BOTS list verbatim so
   the user can decide whether to add any to the allowlist (baked into `gh-renovate-triage`).

Do not read PR diffs or reason about dependency complexity yourself — the script handles greens and the red agents
handle fixes. Keep this session to running the script and dispatching.
