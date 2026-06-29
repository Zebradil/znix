# PKB Routing — shared spec for save-convo and save-note

Loaded by both `save-convo` and `save-note`. Authoritative for routing/frontmatter rules; the skill body wins for what content to extract.

## 0. Required tools (no fallbacks)

These must be on `PATH`. If any is missing, abort and tell the user to install it (e.g. `nix profile install nixpkgs#<tool>`). Do **not** search for alternatives.

- `yt-dlp` — only required when processing YouTube URLs
- `rg`, `fd`, `jq`, `bash` — always required
- The four helper scripts on `PATH`: `pkb-context`, `pkb-fetch-youtube`, `pkb-related`, `pkb-journal-append` (see §1.1)

## 1. Constants & startup helpers

- `KNOW_ROOT` — set via the `$KNOW_ROOT` environment variable (configured per-host in the system). The scripts use this value; override it at the shell for testing: `KNOW_ROOT=/tmp/fake pkb-context`.

At skill start, run **once**:

```bash
pkb-context
```

Returns one JSON blob:
```
{
  "know_root":          "<abs path>",
  "today":              "YYYY-MM-DD",
  "now_min":            "YYYY-MM-DDTHH:MM",
  "tags":               ["..."],          // existing corpus tags, deduped
  "reference_domains":  ["..."],          // existing reference/<domain> subdirs
  "project_slugs":      ["..."]           // existing projects/* basenames
}
```

Reuse those values for the rest of the run. Do **not** re-shell out for `date`, tag harvest, or directory listings.

If `know_root` is missing or the script aborts, stop and surface the error.

### 1.1 Helper scripts

| Script | Purpose |
|---|---|
| `pkb-context` | (above) |
| `pkb-fetch-youtube <URL>` | yt-dlp metadata + cleaned auto-sub transcript → JSON: `{id,title,channel,duration,upload_date,description,has_subs,transcript}`. Cleans `/tmp` after. |
| `pkb-related <kw1> [kw2 …]` | §7 dedup scan → absolute paths, one per line. |
| `pkb-journal-append <basename> <summary>` | Appends `- Captured [[<basename>]] — <summary>` under today's `## Log`, creating the journal file from `templates/daily.md` if missing. Prints the journal path on success. |

These are the **only** bash invocations a skill should issue. Do not assemble equivalent inline pipelines — that defeats the purpose of allowlisting.

## 2. Destination classification (decision tree)

Walk in order. Stop at the first match you are **confident** about. If no branch is clearly correct, fall through to inbox.

1. **Person** — content is primarily about or for one specific person.
   → `$KNOW_ROOT/people/<kebab-name>.md`, base on `templates/person.md`.
2. **Project** — actionable, time-bound, has a goal or open tasks; the user is *doing* something.
   → `$KNOW_ROOT/projects/<kebab-slug>.md`, base on `templates/project.md`.
   → Cross-reference `project_slugs` from `pkb-context`. If a slug matches the topic with ≥0.7 token overlap, propose **append** to that file (or its `index.md`) instead of creating new.
3. **Reference** — durable knowledge, not actionable, fits a clear domain.
   → `$KNOW_ROOT/reference/<domain>/<kebab-slug>.md`, base on `templates/reference.md`.
   → `<domain>` must reuse an existing entry of `reference_domains` when possible. Only propose a new domain when nothing fits, and surface the new-domain choice in the preview.
4. **Journal** — content is explicitly "what I did/observed today" with no broader durability.
   → append to today's journal via `pkb-journal-append`.
5. **Inbox (default fallback)** — anything that is unclear, partially formed, or needs later triage.
   → `$KNOW_ROOT/inbox/<TODAY>-<kebab-slug>.md`, base on `templates/inbox.md`.

You **must** propose the destination and wait for user confirmation via `AskUserQuestion` (Save / Edit destination / Cancel; recommended path first). Never write without confirmation.

## 3. Frontmatter assembly

Templates use Templater syntax (`{{title}}`, `{{date:...}}`). Substitute manually.

Per type:
- **inbox**: `captured: <now_min>`
- **project**: `status: active`, `tags: [...]`, `started: <today>`
- **reference**: `tags: [...]`, `source: <URL or origin string>`
- **person**: `birthday:` (empty unless known), `tags: [...]`
- **journal**: `tags: []`

Frontmatter is YAML between two `---` lines at file top. Tags are inline JSON-ish: `tags: [foo, bar]` (quotes optional).

## 4. Tag selection

Use the `tags` array from `pkb-context` — **do not re-harvest**.

Rules:
- Reuse existing tags wherever they fit.
- New tags: lowercase, kebab-case, single concept, no namespace prefix.
- 1–4 tags. Never more than 6.
- For AI-conversation captures (save-convo): always include `ai-chat`.
- For URL/text notes (save-note): no `ai-chat`; derive purely from content.

## 5. Filename rules

- Slugs: ASCII, lowercase, kebab-case, no spaces / underscores / punctuation other than `-`.
- Inbox files: `<today>-<slug>.md`.
- Journal files (managed by `pkb-journal-append`): `journal/<YYYY>/<MM>/<YYYY-MM-DD>.md`.
- Everything else (`projects/`, `reference/<domain>/`, `people/`): `<slug>.md`.
- If a target file already exists and the chosen action is "create", suffix `-2`, `-3`, … until unique.

## 6. Append vs. create

If the proposed destination already exists:

- **Project**: append a new dated section `## <today> — <subtopic>` at the end of the body. Don't touch frontmatter except to add genuinely missing tags.
- **Journal**: handled by `pkb-journal-append`.
- **Reference / Person**: do **not** auto-append. Show the existing file in the preview and ask: append / replace / save under a new slug.
- **Inbox**: collisions on `<today>-<slug>` are rare; suffix `-2`, `-3`, …

## 7. Cross-linking and dedup

```bash
pkb-related <kw1> <kw2> [kw3 …]
```

Pass 2–4 of the strongest topical keywords. For each match (other than the destination itself), include in the body:

```
## Related
- [[<basename-without-ext>]]
```

If any match looks **substantively duplicative** (same topic, >50% overlap), surface this in the preview and propose append-to-that-file as an alternative destination.

## 8. Journal back-pointer

After a successful save (any destination except the journal itself):

```bash
pkb-journal-append <basename-without-ext> "<one-line summary>"
```

The script handles file creation, `## Log` section, and placement.

## 9. Preview format (always shown before any write)

Print exactly:

```
═══ PKB CAPTURE PREVIEW ═══
DESTINATION: <absolute path>
ACTION:      create | append | append-with-confirm
RELATED:     <count> existing notes (listed in body)
TAGS:        [t1, t2, ...]

--- frontmatter ---
<yaml>
--- body ---
<rendered markdown>
--- end preview ---
```

Then ask via `AskUserQuestion`:
- **Save** (recommended) — write the file and run `pkb-journal-append`
- **Edit destination** — let the user pick a different path / type
- **Cancel** — abort, write nothing

## 10. Hard rules

- Never write to `archive/` or `templates/`. Read-only.
- Never include secrets, full email addresses, phone numbers, or physical addresses (per `KNOW_ROOT/CLAUDE.md`). If detected in the input, redact with `[redacted]` and warn in the preview.
- Never run `git` commands inside `KNOW_ROOT` — `obsidian-git` handles commits.
- Always show the preview. Never auto-write, even when the destination seems obvious.
- Always substitute Templater placeholders manually. Never write raw `{{title}}` or `{{date:...}}` to disk.
- Operate from any cwd. Use absolute paths everywhere.
- Use only the four helper scripts in §1.1 for shell work — no inline equivalents.
