---
name: export-session
description:
  Export a Claude Code or opencode session transcript as a readable chat log (Markdown or JSON). Trigger when the user
  wants to "export this session", "save the transcript", "share a session", "what did we decide in that session", or
  wants an older session's context carried into a new one.
allowed-tools: Bash(session-export *), Read
---

# export-session

`session-export` renders a session as a chat between the user and the agent, from either store: Claude Code's `.jsonl`
transcripts or opencode's SQLite database. Session metadata (title, model, tool counts, token totals) goes in a header.

```bash
session-export                      # fzf picker over this project's sessions, both tools
session-export <session-id|path>    # a specific session; the source follows from the id
session-export --list               # profile / id / time / size / title for this project
session-export --all                # picker over every project on this machine
session-export --list --all         # same, as a list; adds a project column
```

Sessions are scoped to the current directory, unless `--all` widens the picker and `--list` to every project the
machine has ever run a session in — that is the flag for "which session was it, in some other repo". `--all` adds a
project column derived from the transcript's directory, shortened against `$HOME` and left-truncated so the
distinctive tail survives. Passing an explicit session id or path never needs `--all`: id lookup is already global.

A session id is enough to identify the source — opencode ids start with `ses_`, Claude ids are UUIDs — so no flag
selects the tool.

Every Claude profile on the machine is searched, not just the running one: each profile is its own config dir
(`~/.config/personal-claude`, `~/.config/trv-claude`, …) and `CLAUDE_CONFIG_DIR` names only the active one, so the
first column shows which profile a session belongs to.

## Which mode

| Flag      | Use when                                                                                                     |
| --------- | ------------------------------------------------------------------------------------------------------------ |
| _(none)_  | Reading or sharing. Prose, decisions, and a count line per run of tool calls; no tool inputs or output.      |
| `--llm`   | **Reseeding a fresh session.** Prose, decisions and questions only — minimal header, no stats, no tool calls. |
| `--full`  | You need the actual calls and what they returned (truncated to 20 lines each), plus patched-file lists.      |
| `--debug` | Auditing the agent: every tool input, hook firing, attachment, and opencode reasoning text, untruncated.     |
| `--json`  | Normalized `{session, events}` instead of Markdown. Combines with any of the above.                          |

Output goes to stdout — redirect it, or pipe it wherever it needs to land.

## Reseeding a session

When the user wants to continue an older session cheaply rather than reloading it whole, `--llm` is the intended path:

```bash
session-export <session-id> --llm > /tmp/prior-session.md
```

Then read that file into the new session. It keeps the durable content — the prompts, the agent's prose, every question
with its options and the user's answer, and any away-summary — and drops the perishable content: stale command output
and the calls that produced it, which a fresh agent can regenerate in seconds.

## Things worth knowing

- **Answers to a question are not messages.** Claude records them on the result half of the tool-call pair (with any
  free-text notes); opencode records them on the call itself. Either way, a reader that only looks at prose misses the
  entire substance of a question-driven session.
- **Secrets are redacted unconditionally** (`sk-ant-`, `gh*_`, `github_pat_`, `AKIA`, `xox*-`, `AGE-SECRET-KEY-`, PEM
  private keys). It is a prefix filter, not a guarantee — skim a `--full` or `--debug` export before sending it
  anywhere.

### Differences by tool

| | Claude Code | opencode |
| --- | --- | --- |
| Reasoning | Never in the transcript — only a replay signature survives, so no mode can show it. `--debug` marks where thinking occurred. | Recorded in full. Shown at `--debug` only: it is bulky and the most sensitive thing in the log. |
| Header extras | Effort, client mode, permission mode, skills | Agent, session slug, input/reasoning tokens, cost |
| Subagents | Inline in the parent transcript | Separate child sessions; the parent shows the `task` call and its result. Export a child by its own id. |
| Not exported | — | Provider metadata blobs and the diffs inlined on user messages; `--full` shows patched-file lists instead. |
| Ordering | File order — a rewound or edited message may show the abandoned branch as well. | Database order by creation time. |
