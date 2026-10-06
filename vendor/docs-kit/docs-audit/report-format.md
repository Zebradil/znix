# Gap report format

The gap report lives at `docs/.audit.md` in the consuming project. `docs-audit` writes it; `docs-write` reads it, picks one gap, and updates that gap's status. Plain Markdown, parseable line by line.

## Structure

1. `# Docs audit: <project>` followed by a header list: `- commit: <short sha audited>`, `- date: <YYYY-MM-DD>`, `- summary: <n> high, <n> medium, <n> low`.
2. One section per gap, ordered by severity (high first), then by ID.
3. A final `## Not checked` section: one bullet per check that did not run, or ran on a stand-in, with the reason. Omit it when every check ran in full.

A gap is the heading `## G<n>: <title>` and everything up to the next `## ` heading. Its body is a list of `- <field>: <value>` items, fields in this order:

| Field | Values | Meaning |
|---|---|---|
| `status` | `open` \| `partial` \| `resolved` | `docs-audit` writes `open`; `docs-write` or `docs-bootstrap` sets `partial` or `resolved` |
| `severity` | `high` \| `medium` \| `low` | high: a reader cannot get started or is told something false; medium: a task, command, or idea has no page; low: minor inaccuracy, thin help text, cosmetic |
| `area` | `site.yaml` \| `getting-started` \| `guides` \| `concepts` \| `reference` \| `readme` | Part of the content contract the gap belongs to |
| `fix-by` | `docs-bootstrap` \| `docs-write` \| `refgen` \| `code` \| `human` | Who closes it. `refgen`: regenerate and commit reference pages. `code`: a source change, e.g. help text. `human`: an owner decision |
| `target` | a path | File to create or edit, relative to the repository root |
| `depends-on` | `G<n>`, comma separated | Optional. Gaps that must close first |
| `evidence` | nested list | One item per fact: `` `path:line` `` or `` `path:start-end` `` plus what it shows, or `` `command` `` plus the decisive output line. An item with neither starts with `unverified:` |
| `action` | one paragraph | What to do, sized for one run of the `fix-by` owner: one page to write, or one set of edits to one file. Names the seed material to draw from |
| `issue` | `#<n>` | Optional. Issue filed for this gap |
| `resolution` | one line | Optional. Added by `docs-write` or `docs-bootstrap`: commit or PR, and what is left when `partial` |

IDs are stable across runs: a re-audit keeps the ID of every gap it still finds, drops gaps it no longer finds, and numbers new gaps after the highest ID in the previous report.

## Example

````markdown
# Docs audit: kasha

- commit: 9ef1368
- date: 2026-09-27
- summary: 1 high, 1 medium, 0 low

## G2: README box retention defaults disagree with code

- status: open
- severity: high
- area: readme
- fix-by: docs-write
- target: README.md
- evidence:
  - `README.md:132-133` says the box keeps a generation younger than `M` or among the `N` newest (main `N=5, M=4wk`)
  - `src/retention.rs:39-51` `Policy::boxed()`: newest 3 (main) / 1 (non-main), count only; used by `src/gc.rs:65`
- action: Rewrite the box-sweep bullet in README.md:132-133 to state the box policy from `src/retention.rs:39-51`; the remote defaults stay in the remote-sweep bullet.

## G8: No guide for running a remote GC sweep

- status: open
- severity: medium
- area: guides
- fix-by: docs-write
- target: docs/src/content/docs/guides/remote-gc.md
- depends-on: G1
- evidence:
  - `kasha gc --help` lists `--grace-hours`, `--main-keep`, `--main-age-weeks`, `--other-keep`, `--other-age-weeks`; no README line mentions them
  - `README.md:134-137` covers the remote sweep in four lines
- action: Write a how-to for `kasha gc` run by hand and from `.github/workflows/gc.yml`: credentials, `--dry-run` first, retention overrides. Seed from README.md:130-137 and `src/gc.rs:1-9`.

## Not checked

- CLI coverage: no hand-written pages exist (G1); README used as the stand-in.
````
