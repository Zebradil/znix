---
name: weekly
description: Generate a weekly report of substantial topics since last Friday, grouped from the worklog (auto-recorded per session) plus per-profile sources (GitHub PRs, Jira). Trigger on "/weekly", "weekly report", "what did I do this week".
allowed-tools: Bash, Read, Write
---

# weekly

Produce a short weekly report of **substantial topics only** — the kind pasted
into a team update. The `worklog-prep` helper gathers every worklog record and
source item in the window and hands you one JSON blob; your job is to **compress
many small items into a few real topics**.

Unlike standup, weekly is **non-destructive**: it reads the archive plus the
live worklog, never drains, never advances a marker. Run it as often as you like.

## Window

Default window is the **latest Friday 13:00 strictly before today** (run on a
Friday, that's the previous week's Friday — a full work week). To report a
different span, pass a date or datetime in the invocation args (e.g.
`2026-07-01` or `2026-07-01T09:00`).

## 1 — Prep

```bash
prep="$CLAUDE_CONFIG_DIR/hooks/worklog-prep"
"$prep" weekly                 # default: since last Friday 13:00
# "$prep" weekly 2026-07-01     # arbitrary start, if the args gave one
```

If the helper errors that config is missing, worklog isn't enabled for this
profile — tell the user and stop.

Read the JSON:

- `sessions[]` → every session in the window (`title`, `cwd`, `turns`, ts).
- `trivialCount` → throwaway sessions folded away.
- `sources[]` → each `{name, output}` (PRs, Jira, …), or `{name, error}`.
- `window.startDate` / `window.endDate` → the reporting period.
- `report_path` → where to Write the report.

## 2 — Synthesize into substantial topics

The raw data is intentionally noisy: one topic often spans several sessions,
several PRs, and several Jira tasks (e.g. three sessions + two PRs on the same
migration = **one** bullet). Do the grouping aggressively.

Rules:

- **Substantial topics only.** Drop routine noise (lockfile bumps, quick
  one-offs, `trivialCount`). If it wouldn't be worth mentioning to the team,
  cut it.
- **Group across sources.** Merge worklog sessions with the PRs/Jira items that
  belong to the same effort. One coherent piece of work → one bullet.
- **Several words each.** Each bullet is a short phrase, not a sentence and not
  a transcript. Aim for a handful of bullets total, roughly like:

  ```
  - Kubevirt monitoring for VM phase/states
  - Oncall dashboards for Harvester
  - GitHub custom runners: multiple pools per group
  ```

- **No name/heading of your own beyond the period.** The report's header is the
  reporting period (e.g. `## 2026-07-04 – 2026-07-10`); the body is just the
  bullets. The user pastes it into the shared team doc and may add their own
  notes to individual topics.

Write the report to `report_path` with the Write tool.

## 3 — Done

Print the report and tell the user it was saved to `report_path`. No marker, no
rotation — re-running just regenerates.
