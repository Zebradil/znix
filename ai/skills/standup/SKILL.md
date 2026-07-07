---
name: standup
description: Generate a standup report of everything you did since the last standup, from the worklog (auto-recorded per session) plus per-profile sources (GitHub PRs, Jira). Trigger on "/standup", "standup report", "what did I do since last standup", "what have I been working on".
allowed-tools: Bash, Read, Write, AskUserQuestion
---

# standup

Produce a standup report covering **everything since the last standup**. The
worklog Stop hook records one line per session-turn into `current.jsonl`; this
skill drains that file, fetches extra per-profile sources, and synthesizes the
report. Draining is destructive-by-design (the drained file is archived, and
every report is saved), so "since last standup" is defined by construction.

**Dry-run** (`--dry-run`, `dry`, or `preview` in the invocation args): produce
an ephemeral status report without rotating anything — read `current.jsonl` in
place instead of renaming it, don't save the report, don't advance the marker.
Use it to peek at the current window; the next real standup still covers it.

If the invocation args contain `--dry-run`, `dry`, or `preview`, export
`dry=1` before running the blocks below (otherwise leave it unset):

```bash
dry=1   # only when dry-run requested; else omit this line
```

## 0 — Load config

```bash
cfg="$CLAUDE_CONFIG_DIR/worklog-sources.json"
cat "$cfg"
```

This is the single source of truth: `profile`, `worklog_dir`, and `sources`
(a list of `{name, cmd}`). If the file is missing, tell the user worklog isn't
enabled for this profile and stop.

Bind for the rest of the run:

```bash
dir=$(jq -r .worklog_dir "$cfg")
now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
ts=$(date -u +%Y%m%dT%H%M%SZ)
since=$(cat "$dir/last-standup" 2>/dev/null || true)
```

## 1 — Drain the worklog (atomic)

Rename, don't read-then-truncate: a background session's Stop hook may append
concurrently, and rename keeps those records for the *next* standup instead of
losing them.

Dry-run reads the live `current.jsonl` in place — no rename, no archive — so the
next real standup still sees these records.

```bash
mkdir -p "$dir/archive" "$dir/reports"
if [ ! -s "$dir/current.jsonl" ]; then
  drained=""
elif [ -n "$dry" ]; then
  drained="$dir/current.jsonl"          # peek in place, leave it for next run
else
  mv "$dir/current.jsonl" "$dir/archive/$ts.jsonl"
  drained="$dir/archive/$ts.jsonl"
fi
```

If `drained` is empty: there is nothing since the last standup. Offer to show
the most recent saved report (`ls -t "$dir/reports"/*.md | head -1`) and stop.

## 2 — Collapse sessions

Each session emitted many records (one per turn). Group by `session`: the
**last** record holds the final `title` (fall back to `last_prompt` when
`title` is null), and the **record count** is the activity length.

```bash
jq -s '
  group_by(.session)
  | map({
      session: .[0].session,
      cwd:     (.[-1].cwd),
      title:   (.[-1].title // .[-1].last_prompt),
      turns:   length,
      first:   (.[0].ts),
      last:    (.[-1].ts)
    })
  | sort_by(.first)
' "$drained"
```

Treat sessions with `turns < 2` as trivial — collapse them into a one-line
"also: N quick sessions" note rather than listing each.

If `since` is empty (no prior marker), use the earliest `first` above as the
window start for the sources below; if there were no records either, default to
7 days ago. Step 3 computes this window start runnably.

## 3 — Fetch sources

For each entry in `sources`, substitute `{{since}}` with the window start
**as a date** (`YYYY-MM-DD` — most CLIs like `gh search --updated` want a date,
not a datetime), run the `cmd`, and capture its raw output. A failing source is
non-fatal — note it as unavailable and continue.

```bash
since_date=${since%%T*}                        # full-ISO marker → date-only
if [ -z "$since_date" ]; then                  # no prior marker: fall back
  # earliest drained record, else 7 days ago (BSD/macOS form, then GNU/Linux)
  since_date=$(jq -rs 'map(.ts) | min // empty' "$drained" | cut -dT -f1)
  [ -n "$since_date" ] || since_date=$(date -u -v-7d +%Y-%m-%d 2>/dev/null || date -u -d '7 days ago' +%Y-%m-%d)
fi
jq -r '.sources[] | @base64' "$cfg" | while read -r s; do
  name=$(echo "$s" | base64 -d | jq -r .name)
  cmd=$(echo "$s" | base64 -d | jq -r .cmd | sed "s|{{since}}|$since_date|g")
  echo "## $name"; eval "$cmd" 2>&1 || echo "(source unavailable)"
done
```

## 4 — Synthesize the report

Write markdown, grouped by day (local time, from each record's `ts`), most
recent day first. For each day:

- Bullet the substantive sessions: the `title` as the headline, the repo/dir
  (basename of `cwd`) as context. Merge sessions that are obviously the same
  piece of work.
- Append the collapsed "N quick sessions" note if any.

Then a section per source (GitHub PRs, Jira, …) with its fetched items, deduped
against what the worklog already says (a merged PR and its session are the same
work — mention once).

Keep it standup-length: what got done, grouped, skimmable. Not a transcript.

## 5 — Save and advance the marker

**Dry-run: skip this whole step.** Print the report, tell the user it's a
preview — nothing was saved, the worklog was not rotated, the marker did not
move — and stop.

```bash
# (write the report to $dir/reports/$ts.md via the Write tool, then:)
printf '%s\n' "$now" > "$dir/last-standup"
```

Print the report to the user and tell them it was saved to
`reports/$ts.md`. The `last-standup` marker now bounds the next run.
