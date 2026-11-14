---
name: orchestrate-implementation
description:
  Run a long implementation from a spec as an orchestrating session: a milestone roadmap and a hand-over document, one
  implementer and one reviewer subagent per milestone in git worktrees, usage-limit checks with a self-scheduled
  wake-up after the five-hour reset, and acceptance checks on real machines. Use when the user asks to implement a
  spec or a large feature that will not fit one session, to "orchestrate subagents", or to resume such work after a
  usage reset. Claude Code only: it relies on its subagents, SendMessage, CronCreate and status-line data.
---

# orchestrate-implementation

The orchestrating session plans, delegates, gates, reviews and merges; subagents write the code. The orchestrator
keeps its own context small: it reads reports, diff stats and test results, never whole implementations, and never a
subagent's transcript file.

## Start

1. Read the spec's headings (`rg -n '^#' docs/spec.md`), the glossary and any ADRs. Estimate the size in milestones.
2. Ask the user once, with `AskUserQuestion`: where the work lands (remote, CI, merge rules), when to call them in
   (usually only for real blockers), model and effort, and ownership (personal or employer: it decides what may go
   into docs and where knowledge is kept). Save the answers as a memory, so a resumed session keeps the mandate.
3. Write three documents and commit them:
   - `docs/roadmap.md`: a milestone table (scope, spec sections, depends on, status) and a dated log.
   - `docs/handover.md`: "Where things stand" first (milestones done; for each one in flight: worktree, branch,
     agent IDs, commit or uncommitted state, backups, next step; the watcher's task ID and any wake-up's cron job ID),
     then how each milestone runs, notes per milestone (APIs the
     next milestone needs, review findings still open), the usage-limit policy, cautions, and a prompt for a new
     session. Keep it current after every merge and before every pause: it is the fallback if the session dies.
   - `docs/architecture.md`: module ownership per milestone, data flow, seams, error model, testing.
4. Group milestones into waves of independent ones that run in parallel. Choose module ownership so parallel
   milestones touch different files. When two milestones of a wave need the same small helper, write it on `main`
   first.

## Each milestone

1. **Worktree.** A branch `wt/<yymmdd-HHMMSS>-<slug>` from `main` in `.worktrees/`.
2. **Implementer** (Opus; effort `xhigh` for subtle milestones, `high` otherwise; background). The prompt gives: the
   worktree and "do not touch main or other worktrees"; commit conventions from the global instructions (no attribution trailers); what to
   read (glossary, architecture, ADRs, the spec sections by number, not the whole spec); the toolchain; which modules
   it owns; the scope as a numbered list with the hand-over notes for it; done-when (tests, lint, format, package
   build); and the final message: a word limit (200–300), no code, public API, deviations and spec ambiguities with
   section numbers, done-when results.
3. **Gate** yourself: run the tests and the linter in the worktree; look at `git diff --stat`.
4. **Reviewer** (Opus, same effort, background), read-only: same documents, a numbered list of the spec's rules for
   the area, probes only under the scratchpad, no SSH. The report (at most 450 words) ranks findings, each with
   `file:line`, a concrete failing input and wrong output, a one-line fix, and confirmed or plausible. Reviews found
   real defects in every milestone; never skip them.
5. **Fix round.** Send the findings to the implementer with `SendMessage`: it keeps its context, which is cheaper than
   a new agent. Accept a deviation only when it is argued from the spec or an ADR. After a large fix round, send the
   result back to the same reviewer for a verification pass; repeat until it holds. A small spec gap found on the
   way is yours to decide; record the decision in an ADR.
6. **Merge.** Squash-merge into `main` with one `feat: … (Mn)` commit, rerun the tests on `main`, remove the worktree
   and branch, update the roadmap and the hand-over, commit.

### Git details that cost time

- A milestone can start on unmerged work: create its worktree from the base branch, `git apply --index` the base's
  diff (staged), and tell the implementer to leave its own changes unstaged and never touch the index (no `add`,
  `commit`, `stash`, `reset`). Once the base is committed, `git reset --soft <base commit>` in the new worktree (check
  first that `git diff --cached <base commit>` is empty); only its own changes remain.
- After a base was squash-merged, merging a branch built on it conflicts (add/add). Apply only its own diff instead:
  `git diff --binary <base tip> <branch> | git apply --index` on `main`, then check that `git diff --cached <branch>`
  is empty outside the docs `main` changed meanwhile.
- `Cargo.lock` (or any lock file) conflicts: take one side, then let the build tool regenerate it offline.
- Commits signed through a hardware or 1Password key need the user's touch. While they are away a commit fails
  ("failed to fill whole buffer", "failed to write commit object"). Never bypass signing. Keep working uncommitted,
  back up `git diff --binary` and a tar of the untracked files to the scratchpad, note it in the hand-over, and commit
  when the user is back. Approval prompts time out, so try one commit at the start of each wake-up.

## Usage limits and the self-wake-up

The five-hour window ends a session abruptly, and a session resumed later starts with cold caches. Pause before the
limit inside the same session and wake it up after the reset.

**Source.** Claude Code passes the rate limits to the status-line command on stdin. The znix status line
(`ai/statusline-command.sh`) saves them to `$CLAUDE_CONFIG_DIR/state/rate-limits.json` as `{t, rate_limits}`, and the
profile's `refreshInterval` re-runs it every 60 s: without the timer, status-line events stop while the main session
waits on background subagents, and the file goes stale. Outside znix, a status-line command needs both parts.

**Read it** before spawning agents and after each milestone:

```bash
jq -c '{age_s: (now - .t | floor), rate_limits}' "$CLAUDE_CONFIG_DIR/state/rate-limits.json"
```

`rate_limits.five_hour.used_percentage` (0 to 100, may be a decimal) and `.resets_at` (epoch seconds) matter.
`rate_limits` appears only after the session's first API response, and Claude Code drops a window once its `resets_at`
passes, so a missing `five_hour` in a fresh file means the window reset. An `age_s` above a few minutes means the
status line is not saving: check `statusLine` in `settings.json` before trusting the numbers. Convert the epoch with
`/bin/date -r <epoch>` on macOS (GNU `date` from Nix takes `-d @<epoch>`).

**Watch it** with a background command that exits, and so notifies the session, at 80 % or when the file is missing or
older than ten minutes:

```bash
f="$CLAUDE_CONFIG_DIR/state/rate-limits.json"
while :; do
  read -r age pct < <(jq -r '"\(now - .t | floor) \(.rate_limits.five_hour.used_percentage // 0 | floor)"' "$f") ||
    { echo "no usage file: $f"; exit 1; }
  [ "$age" -gt 600 ] && { echo "usage file stale: ${age}s"; exit 1; }
  [ "$pct" -ge 80 ] && break
  sleep 60
done
jq -c '{age_s: (now - .t | floor), rate_limits}' "$f"
```

**At 80 %:** start nothing new and let running agents finish. Record their results and every in-flight state in the
hand-over. Then schedule a one-shot `CronCreate` a few minutes after `resets_at` (pin minute, hour, day and month;
`recurring: false`) and check it with `CronList`. The prompt must stand on its own, for example:

> The five-hour usage window has reset. Resume orchestrating <project>: read the usage file (`jq -c '{age_s: (now -
> .t | floor), rate_limits}' <file>`), then continue from the "Where things stand" section of docs/handover.md. Try
> one signed commit; if it works, commit and merge what is waiting, otherwise keep working uncommitted. <the next
> two or three concrete steps>. Keep the usage-limit policy: from 80 % start nothing new, record state in
> docs/handover.md, and schedule another one-shot wake-up at the next reset.

Cron jobs live only as long as the session: if it exits, the hand-over and its new-session prompt take over. Stop the
watcher with `TaskStop` when the work is done.

## Context and compaction

The orchestrator runs for days and its context only grows. The model cannot run `/compact` itself: it is not available
through the Skill tool, and built-in commands in a scheduled prompt arrive as plain text. Make compaction come early
and carry the hand-over instead. At the start, with the user's approval, write the target repository's
`.claude/settings.local.json` (not committed):

```json
{
  "autoCompactWindow": 300000,
  "hooks": {
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Keep verbatim: each milestone in flight with its worktree, branch, agent IDs and next step; the watcher task ID; cron job IDs; open review findings; the usage-limit policy.'"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "compact",
        "hooks": [
          {
            "type": "command",
            "command": "awk '/^## /{p=($0==\"## Where things stand\")} p' \"$CLAUDE_PROJECT_DIR/docs/handover.md\""
          }
        ]
      }
    ]
  }
}
```

- `autoCompactWindow` (tokens, 100000 to 1000000) compacts long before the model's limit; without it a 1M-context
  model compacts at about 967K tokens. The user can also start the session with `--autocompact <tokens>`.
- The `PreCompact` hook's output steers the compaction summary. The `SessionStart` hook with matcher `compact` adds
  "Where things stand" to the compacted context, so the hand-over must be current before the window fills.
- Whether a running session picks up a new `settings.local.json` is unverified: check with `/hooks`, or ask the user
  to restart with `--continue`.
- The status line's `context_window.used_percentage` is measured against the full window, not `autoCompactWindow`,
  so it does not tell when compaction will run.
- Subagents have their own windows and compact on their own; a fresh implementer per milestone keeps them small.

## Permissions in auto mode

- The auto-mode classifier blocks commands that run on other machines (`ssh`, tools that SSH) from subagents ("Remote
  Shell Writes"). A one-command grant through `/permissions` reaches the main session, not a subagent.
- What passed: one reviewable script under the scratchpad, written by the orchestrator and run from the main session
  (in the background when long). Put all remote steps of a phase into one such script so one approval covers them.
- Stay in auto mode; the user approves by hand only when something is blocked. Never work around a denial.

## Acceptance checks on real machines

- Ask which machines may be used (personal only), what may be written there (builds into the store, a scratch
  directory), and when the user is at the keyboard: every SSH key use may need their touch. Say before each burst.
- Never write to the user's repositories: `git clone --local` into the scratchpad and make scratch branches there.
  Nothing is deployed, switched or activated.
- Committed records (ADRs) use generic names: no hostnames, addresses, user names or real configuration names.
- Check first what the machines hold: nodes often keep only their current system generation, so "compare two
  generations" may have to become "build an older revision on the node and compare".
- Useful tricks:
  - a hanging SSH target without any network: `NIX_SSHOPTS='-o ProxyCommand=sleep 600'`;
  - a user SSH configuration without editing `~/.ssh/config`: a scratch file whose first `Host` block sets the options
    and which then has `Include ~/.ssh/config`, passed with `-F`;
  - macOS limits Unix socket paths to about 104 bytes, so `ControlPath` goes under `/tmp`, not the scratchpad;
  - count SSH handshakes from the node's journal (`journalctl -u sshd --since @<s> --until @<e> | grep -c 'Accepted
    publickey'`), with a few seconds' gap between steps so neighbouring connections don't fall into the window;
  - a stale or unknown host key: a scratch known-hosts file with `StrictHostKeyChecking=accept-new`;
  - ship a repository from macOS to Linux with `COPYFILE_DISABLE=1 tar` (otherwise `._*` files break git), and source
    with `git archive`; build there with `nix build path:<dir>`;
  - check the machine's own network and substituters before blaming the tool under test.
- zsh: `"$c:flake.lock"` applies the `:f` modifier; write `"${c}:flake.lock"`.

## Talking to the user

Report in short lines: what was merged, what is running, what blocks. Ask with `AskUserQuestion` only for real
blockers (an ambiguity that changes behaviour, a missing machine or credential, an approval). When a subagent reports,
relay what matters; the user does not see its report.
