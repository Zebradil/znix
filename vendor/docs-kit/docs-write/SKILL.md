---
name: docs-write
description: Write one docs page, or fix one README passage, to close one gap from the docs-audit report (docs/.audit.md), every claim grounded in the code. Use when asked to write docs, fix a docs gap, close the next docs gap, or run docs-write on a gap ID such as G3.
---

# docs-write

Close exactly one gap from `docs/.audit.md` in the consuming project (the current repository): write or extend its `target`, update the gap, open one PR. The report format, field meanings included, is [../docs-audit/report-format.md](../docs-audit/report-format.md).

The page is **grounded**: every statement of behavior, default, flag, path, or number traces to a source read this run (code, tests, help output, existing docs, ADRs). A claim with no source, or a command you could not run, goes in an aside, never into plain prose:

```markdown
:::caution[Unverified]
What you believe and why it is unconfirmed, e.g. "not run: needs S3 credentials".
:::
```

## 1. Pick the gap

Read `docs/.audit.md` from the main checkout. No report: say so, suggest `docs-audit`, stop.

- **Named** (`G3`): take it. Refuse, naming the reason, when `fix-by` is not `docs-write`, `status` is `resolved`, or a `depends-on` gap is not `resolved`.
- **Not named**: from gaps with `fix-by: docs-write`, `status` `open` or `partial`, and every `depends-on` gap `resolved`, take the highest severity, then the lowest ID.

Nothing qualifies: say what blocks the candidates (e.g. every page gap `depends-on` an open `docs-bootstrap` gap), suggest `docs-bootstrap` or `docs-audit`, stop.

A `partial` gap: its `resolution` says what is left; that is this run's scope.

## 2. Read the sources

Done when you have read every `evidence` path and every seed the `action` names, the code behind each behavior the page will describe, and its tests. Then read the project voice: README, `CONTEXT.md` (use its terms, avoid its _Avoid_ words), and the existing pages nearest the target.

Build the CLI into a temp dir as in [docs-audit check 3](../docs-audit/SKILL.md#checks) and read `--help` for every command the page names.

## 3. Write

Work in a git worktree on a feature branch. Follow the project's `AGENTS.md`/`CLAUDE.md` for worktree location and branch naming; default branch name `docs/<gap-id>-<slug>`.

The gap's `area` sets the page's mode:

| Area | Mode | Shape |
|---|---|---|
| `getting-started` | tutorial | One path from nothing to a visible result; every step runnable; no options or alternatives |
| `guides` | how-to | Title names the task; prerequisites, then numbered steps; assumes the reader knows the basics |
| `concepts` | explanation | How it works and why; prose and tables, no step lists; link the ADRs for rationale |
| `readme`, `site.yaml` | fix in place | Edit only the lines or fields the evidence cites; revalidate `site.yaml` as in docs-audit check 1 |

New page: Starlight front matter with `title` and a one-sentence `description`, then body without an H1. Existing target: extend it; keep the hand-written sections and correct a false sentence in place.

- Concise and task-oriented: short sections, commands in fenced blocks with a language tag, defaults in tables.
- Link the generated reference for flag lists instead of copying them. `reference/` is generated: link it, leave it untouched, and leave `site.yaml` alone unless the gap's `target` is `site.yaml`.
- Link only pages that exist, with relative URLs ending in `/` (from `concepts/x.md`: `../../reference/cli/kasha-gc/`); the site is served under `/<project>/`. Files outside the site, such as ADRs, link by `<repo>/blob/main/<path>` with `repo` from `site.yaml`.
- Match the voice you read: person, tense, heading case, code-block style.
- Where the code and existing docs disagree, the code wins. Name the disagreement in the PR body, with the gap that covers it when one exists; the page states only the code's behavior.

## 4. Verify

Done when:

- every command or snippet on the page was run in a temp dir (`mktemp -d`) with output matching what the page says, or sits in an Unverified aside naming why it was not run (credentials, network, another OS). Nothing runs against the user's real config, store, or remote. Behavior you cannot run is grounded by running the tests that cover it (build output in the temp dir);
- every behavior sentence has a source from step 2; list those sources as `path:line` in the PR body;
- `docs/package.json` present: the site builds in the worktree with the new page.

## 5. Update the gap and ship

In the gap: set `status` to `resolved`, or `partial` when part of the `action` is unwritten or stated only inside an Unverified aside, and add `- resolution: branch <branch>; <what is left, when partial>`. `docs/.audit.md` tracked by git: edit it in the worktree and commit it with the page. Untracked: edit the main checkout's copy after opening the PR.

One focused commit, Conventional Commits unless the project says otherwise: `docs: <what the page adds>`. Push and open a PR with `gh pr create`: what the page covers, sources, what is Unverified and why, and `Closes #<n>` when the gap has an `issue`.

Reply with the PR URL, the gap ID, and its new status.
