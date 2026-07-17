---
name: standup
description: Generate a standup report of everything you did since the last standup, from the worklog (auto-recorded per session) plus per-profile sources (GitHub PRs implemented/reviewed, automated-PR counts, commits, Jira). Trigger on "/standup", "standup report", "what did I do since last standup", "what have I been working on".
allowed-tools: Bash, Read, Write
---

# standup

Produce a standup report covering **everything since the last standup**. A Stop
hook records one line per session-turn into `current.jsonl`; the `worklog-prep`
helper drains that file, fetches per-profile sources, and hands you a single
JSON blob. Your only job is the part a script can't do: **group the many small
records into coherent work and write it up**.

Draining is destructive-by-design (the drained file is archived, the marker
advances only after a report is written), so "since last standup" is defined by
construction.

**Dry-run** (`--dry-run`, `dry`, or `preview` in the invocation args): peek at
the current window without rotating anything — read `current.jsonl` in place,
don't save the report, don't advance the marker. The next real standup still
covers it.

## 1 — Prep (deterministic; the script does it all)

```bash
prep="$CLAUDE_CONFIG_DIR/hooks/worklog-prep"
# add --dry-run only when the invocation asked for a dry-run / preview:
"$prep" standup            # or: "$prep" standup --dry-run
```

If the helper errors that config is missing, worklog isn't enabled for this
profile — tell the user and stop.

Read the JSON it prints:

- `empty: true` → nothing since the last standup. Offer to show `latest_report`
  and stop.
- `sessions[]` → the substantive work, one entry per session (`title`, `cwd`,
  `turns`, `first`/`last` timestamps), already collapsed and sorted.
- `trivialCount` → count of throwaway sessions (`turns < 2`) folded away.
- `sources[]` → each `{name, output}` (or `{name, error}` if it failed).
- `report_path` → where to Write the report (null on dry-run).
- `window.startDate` → start of the source window.

## 2 — Synthesize (your judgment)

Write markdown grouped by day (local time, from each session's `first` ts), most
recent day first. For each day:

- Bullet the substantive sessions: `title` as the headline, basename of `cwd` as
  context. **Merge sessions that are obviously the same piece of work.**
- Append a "also: N quick sessions" note if `trivialCount > 0`.

Then a section per source with its items, **deduped against the worklog** — a
merged PR and the session that produced it are the same work, mention it once.
Each source may carry an `instruction` describing how to render it — **follow
it** (e.g. a source may already be a count you report as-is rather than
enumerate). Absent → list items, deduped.

Keep it standup-length: what got done, grouped, skimmable. Not a transcript.

Write the report to `report_path` with the Write tool.

## 3 — Commit

**Dry-run: skip this step.** Print the report and tell the user it's a preview —
nothing saved, worklog not rotated, marker not moved.

Otherwise advance the marker (this bounds the next run's source window):

```bash
"$CLAUDE_CONFIG_DIR/hooks/worklog-prep" commit standup
```

Print the report and tell the user it was saved to `report_path`.
