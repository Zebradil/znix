---
name: save-convo
description: Summarize the current Claude Code conversation and save it to the personal knowledge base. Trigger when the user asks to "save this conversation", "checkpoint this thread", "capture this session", "save what we just did", or similar phrasing — regardless of the current working directory.
allowed-tools: Bash(pkb-context *), Bash(pkb-related *), Bash(pkb-journal-append *), Read, Write, AskUserQuestion
---

# save-convo

Summarize the **current conversation** and persist it to the PKB. The goal is not a transcript — it is a synthesized artifact that lets a future Claude (or future you) pick up the work cold, in a fresh session, with no replay needed.

## Step 0 — Load shared spec & context

1. Read `${CLAUDE_SKILL_DIR}/../_pkb-routing.md` in full (use `Bash(cat "${CLAUDE_SKILL_DIR}/../_pkb-routing.md")`).
2. Run `pkb-context` once. Cache the JSON in working memory and reuse `today`, `now_min`, `tags`, `reference_domains`, `project_slugs` for the rest of the run.

## Step 1 — Synthesize the conversation

Working from the current conversation context (no transcript dump), extract:

- **Topic** — one short phrase.
- **Why this matters** — 1–2 sentences. The motivation, not the activity.
- **Key insights / decisions** — bullets. Things now true that weren't true at the start.
- **What was tried** — bullets, each tagged with outcome: worked / didn't / unclear / partial.
- **Open questions** — unresolved threads, things blocked, things to verify.
- **Action items** — as obsidian-tasks lines:
  - `- [ ] <task> 📅 YYYY-MM-DD` if a date was discussed
  - `- [ ] <task>` otherwise
  - Use `⏫ 🔼 🔽` for priority only when the user explicitly said so.
- **Resume context** — the load-bearing section. Write directly to a future Claude:
  - Current state of the world (what's done, what's pending)
  - Where to start
  - Assumptions to keep
  - Things *not* to redo
- **Hot files** — absolute paths referenced or edited during the conversation, each with a one-line purpose. Include the original cwd.

## Step 2 — Classify destination

Per `_pkb-routing.md` §2, using cached `project_slugs`. Bias for `save-convo`:

- **Project** when the conversation was clearly work on a specific effort (and especially if a matching `projects/<slug>.md` already exists — propose append).
- **Inbox** when the conversation was exploratory, scattered, or only ~5 substantive exchanges.
- Almost never: reference, person, journal.

If a matching project file exists, propose **append** with a new dated section `## <today> — <subtopic>`, not a new file.

## Step 3 — Build body

Sections in order (omit empty ones except TL;DR and Resume Context, always required):

```
## TL;DR
<2–4 sentences>

## Resume Context
<directives to a future Claude>

## Key Insights
- ...

## Decisions
- ...

## What Was Tried
- ✅ <thing> — outcome
- ❌ <thing> — outcome
- ❓ <thing> — outcome

## Open Questions
- ...

## Action Items
- [ ] ...

## Hot Files
- `<abs/path>` — <purpose>

## Source
- Model: <model id>
- Date: <today>
- Original cwd: <where the convo happened>

## Related
- [[<wikilink>]]   (per _pkb-routing.md §7)
```

No conversation transcript. No play-by-play. Synthesis only.

## Step 4 — Tags

Always include `ai-chat`. Add 1–3 topical tags from cached `tags` (per `_pkb-routing.md` §4). If the convo is tied to a specific repo or technology, include that as a tag.

## Step 5 — Related notes

Run `pkb-related <kw1> <kw2> [kw3]` with strong topical keywords from the conversation. Include matches in `## Related`.

## Step 6 — Preview, confirm, write

Per `_pkb-routing.md` §9. Show the full preview. Wait for `AskUserQuestion` answer:

- **Save** → write via `Write`, then `pkb-journal-append <basename> "<summary>"`.
- **Edit destination** → re-run classification with a different choice (ask which type).
- **Cancel** → abort, no writes.

## Step 7 — Report

- Absolute path of saved file.
- Absolute path of journal updated (from `pkb-journal-append` stdout).
- One-line summary of what was captured.

## Special cases

- **Thin conversation** (< ~5 substantive exchanges, no real progress): default proposal is `inbox/`. Tell the user the convo is thin and ask whether to proceed.
- **Existing project match**: propose append to that project's main file with a new `## <today> — <subtopic>` section.
- **Convo touched secrets / addresses / phone numbers**: redact in the synthesis, warn in the preview header.
- **Multi-repo convo**: list all touched cwds in `## Source`.
