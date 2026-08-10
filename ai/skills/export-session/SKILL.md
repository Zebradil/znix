---
name: export-session
description:
  Export a Claude Code session transcript as a readable chat log (Markdown or JSON). Trigger when the user wants to
  "export this session", "save the transcript", "share a session", "what did we decide in that session", or wants an
  older session's context carried into a new one.
allowed-tools: Bash(claude-session-export *), Read
---

# export-session

`claude-session-export` renders a session's `.jsonl` transcript as a chat between the user and the agent. Session
metadata (title, model, effort, tool counts, token totals) goes in a header.

```bash
claude-session-export                      # fzf picker over this project's sessions
claude-session-export <session-id|path>    # a specific session
claude-session-export --list               # id / time / size / title for this project
```

## Which mode

| Flag      | Use when                                                                                                    |
| --------- | ----------------------------------------------------------------------------------------------------------- |
| _(none)_  | Reading or sharing. Prose, decisions, and one line per tool call; no tool output.                           |
| `--llm`   | **Reseeding a fresh session.** Same content, minimal header, no statistics. ~19× smaller than the raw file. |
| `--full`  | You need what the commands actually returned (truncated to 20 lines each).                                  |
| `--debug` | Auditing the agent: every tool input, hook firing, and attachment, untruncated.                             |
| `--json`  | Normalized `{session, events}` instead of Markdown. Combines with any of the above.                         |

Output goes to stdout — redirect it, or pipe it wherever it needs to land.

## Reseeding a session

When the user wants to continue an older session cheaply rather than reloading it whole, `--llm` is the intended path:

```bash
claude-session-export <session-id> --llm > /tmp/prior-session.md
```

Then read that file into the new session. It keeps the durable content — the prompts, the agent's prose, every
AskUserQuestion with its options and the user's answer and free-text notes, and any away-summary — and drops the
perishable content, which is mostly stale command output a fresh agent can regenerate in seconds and which would
otherwise be ~75% of the export.

## Things worth knowing

- **Thinking text is never in the transcript.** Blocks are recorded with an empty `thinking` field and only the replay
  signature, so no mode can show it. `--debug` marks where they occurred.
- **Answers to AskUserQuestion are not messages.** They live on the result half of the tool-call pair, including
  free-text notes when the user selected no option — a transcript reader that only looks at `text` blocks misses the
  entire substance of a question-driven session.
- **Secrets are redacted unconditionally** (`sk-ant-`, `gh*_`, `github_pat_`, `AKIA`, `xox*-`, `AGE-SECRET-KEY-`, PEM
  private keys). It is a prefix filter, not a guarantee — skim a `--full` or `--debug` export before sending it
  anywhere.
- Events render in file order. A session where the user rewound or edited an earlier message may show the abandoned
  branch as well.
