---
name: save-note
description: Process arbitrary text or a URL (web page or YouTube video) and save a useful knowledge artifact to the personal knowledge base. Handles fetching, transcript extraction, summarization, and optional clarifying questions. Trigger when the user wants to "save this link", "process this article", "capture this note", "save this video", or pastes text/URL with intent to file it — regardless of the current working directory.
allowed-tools: Bash(pkb-context *), Bash(pkb-fetch-youtube *), Bash(pkb-related *), Bash(pkb-journal-append *), Read, Write, WebFetch, AskUserQuestion
---

# save-note

Take arbitrary input (text, a URL, or a YouTube URL) and save a *useful* knowledge artifact — not a transcript dump. The artifact must stand alone: someone reading it months later should get the value without needing to re-fetch the source.

## Step 0 — Load shared spec & context

1. Read `${CLAUDE_SKILL_DIR}/../_pkb-routing.md` in full (use `Bash(cat "${CLAUDE_SKILL_DIR}/../_pkb-routing.md")`).
2. Run `pkb-context` once. Cache the JSON in working memory — reuse `today`, `now_min`, `tags`, `reference_domains`, `project_slugs` for the rest of the run. Do not re-shell out for these.

## Step 1 — Classify input

The skill argument is the user's input. Classify:

- **Pure URL** — single `https?://...` token, nothing else → fetch and process.
- **URL with commentary** — URL plus surrounding text → fetch URL, treat the surrounding text as the user's framing (preserved in `## My Take`).
- **Pure text** — no URL → process as-is.
- **Empty / very short** (< ~30 chars and ambiguous) → ask 1–3 clarifying questions via `AskUserQuestion` before continuing.

## Step 2 — Fetch (if URL)

### YouTube

URLs matching `youtube\.com/watch`, `youtu\.be/`, `youtube\.com/shorts`:

```bash
pkb-fetch-youtube "<URL>"
```

The script returns one JSON blob with `id`, `title`, `channel`, `duration`, `upload_date`, `description`, `has_subs`, `transcript`. It handles tmp files internally — do not invoke `yt-dlp` directly, do not parse VTT manually, do not chase nix fallbacks.

If `has_subs` is `false`: warn in the preview and summarize from `title + description` only.

### Other URLs

Use `WebFetch` with a prompt like:
> Extract from this page: title, author, publish date, the main thesis, key claims with their evidence, and conclusions. Ignore navigation, ads, and footer boilerplate. Return as structured markdown.

If `WebFetch` fails (paywall, JS-only render), tell the user and ask whether to proceed with what we have or abort.

## Step 3 — Process

Build a useful artifact, not a transcript:

- **Topic** — one phrase.
- **TL;DR** — 2–4 sentences capturing the load-bearing claim.
- **Key points** — bullets. Each one self-contained.
- **Details** — only the parts that need more than a bullet (numbers, mechanisms, caveats).
- **Action items** — only if the content suggests something the user should *do*. Format as obsidian-tasks (`- [ ] ...`, with `📅 YYYY-MM-DD` only if a date is mentioned).
- **My Take** — only if the user supplied commentary alongside the URL.
- **Sources** — every URL touched. Primary URL also goes in frontmatter `source:`. For YouTube, include channel, duration, upload date.

## Step 4 — Optional clarifying questions

Only ask if the material is sparse, ambiguous, or has obvious gaps the **user** (not the source) can fill. Up to 3 questions via `AskUserQuestion`. Skip when the input is rich.

## Step 5 — Idea menu

Pick 1–3 *only when the content actually warrants it*:

- **`## Glossary`** — for jargon-heavy material.
- **`## Counterpoints`** — for opinion pieces.
- **`## Snippets`** — extract reproducible commands or code into fenced blocks.
- **`## Calendar`** — surface dates the user might want to track.
- **Person extraction** — propose creating `people/<slug>.md` as a follow-up.
- **Update existing note** — if `pkb-related` shows a high-overlap match, propose appending instead.

## Step 6 — Classify destination

Per `_pkb-routing.md` §2. Use the cached `reference_domains` and `project_slugs` from Step 0.

Bias for `save-note`:
- **URL-sourced notes** → `reference/<domain>/<slug>.md` is the most common landing.
- **Pure text notes** → `inbox/<today>-<slug>.md` unless clearly project- or reference-shaped.
- **Actionable text tied to a known project** → that `projects/<slug>.md` (append).

## Step 7 — Related notes

Run `pkb-related <kw1> <kw2> [kw3]` with 2–4 strong topical keywords. Include matches in `## Related` per `_pkb-routing.md` §7.

## Step 8 — Body shape

Sections in this order (omit empty ones; TL;DR and Sources are required when input is non-trivial):

```
## TL;DR
## Key Points
## Details
## Action Items     (if any)
## Glossary         (only when warranted)
## Counterpoints    (only for opinion pieces)
## Snippets         (only when extractable code/commands exist)
## Calendar         (only if dates were surfaced)
## My Take          (only if user supplied commentary)
## Sources
## Related
```

## Step 9 — Tags

Per `_pkb-routing.md` §4. Use the cached `tags` array from Step 0. Do **not** include `ai-chat`.

## Step 10 — Preview, confirm, write

Per `_pkb-routing.md` §9. Show full preview, wait for `AskUserQuestion` (Save / Edit destination / Cancel).

On **Save**:
1. Write the artifact via the `Write` tool.
2. Run `pkb-journal-append <basename> "<one-line summary>"`.

## Step 11 — Report

- Absolute path of saved file.
- Absolute path of journal updated (from `pkb-journal-append` stdout).
- For URL inputs: confirmation that the source is captured in `source:` frontmatter and `## Sources` body.
- Any optional sections (idea menu) that were considered and skipped.
