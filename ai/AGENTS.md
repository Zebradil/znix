## General

If your statement is not supported by any evidence, mark it as such. Avoid presenting assumptions as facts.

## Data boundaries

Personal and employer-internal work are separate worlds and never mix.

- The personal knowledge base never receives employer-internal information: internal systems, tickets, incidents,
  colleagues, unreleased plans, or anything that would not be safe in a public repository with secrets removed.
- Classify by path first, content second. Anything under `~/code/github.com/trivago/` or another path with `trivago` in
  it is employer work. Elsewhere, classify by what the content is — employer work living in a personal repository
  (company-related scripts, an internal fork, an OSS project touched for work) is still employer work.
- When the classification is not obvious, ask the user.

## Knowledge base capture

Most sessions produce nothing worth keeping: routine edits, review passes, one-shot questions, anything whose whole
content is the diff. A few produce a durable fact — a decision with its rationale, a root cause, a researched trade-off,
a recipe that works. Those should be captured using the tools of the `personal-knowledge-base` MCP server
(`inbox_capture`, `kb_search`, `reference_create`, …) — a knowledge base named for a company is a different
server and never receives personal-KB content, or the reverse.

Test: **would this be worth having in a few months, and is it unrecoverable from git history or the worklog?** Evaluate
from the end of the first exchange onward; a single research reply can qualify.

When it passes, append one line to the end of the response — never a blocking question:

> Worth keeping in the knowledge base? **yes** / **no** / **continuous** — personal because <one clause>.

- **yes** — capture once, now, with `inbox_capture`.
- **no** — drop the subject for the rest of this session.
- **continuous** — create the note in `reference/` or the matching project, then append each further durable fact to it
  as the session goes. Same test per fact; never append per response.

Rules:

- If the knowledge base tools are not available in this session, never offer. That is the entire gate.
- Never offer for employer-classified work. Name the classification in the offer line so a wrong call is visible.
- Offer at most once per session; a second offer only for a materially different artifact; never after a **no**.
- Only agent-authored text leaves the session. Never write a transcript, a raw session export, or quoted conversation
  into the knowledge base.
- Compress prose, carry data verbatim: tables, commands, config snippets, exact figures and their uncertainty markers
  ("estimate", "unverified", "verify") cross over unchanged.
- `/save-convo` remains the deliberate full-synthesis path, invoked by name. This offer is one cheap capture, not a
  session artifact.

## Code

The Boy Scout Rule: leave the code better than you found it.

## Code comments

Comments explain the code as it is now — the non-obvious _why_. Never write history/changelog comments: no "was X",
"changed from", "previously", "used to be", "now uses". Git holds history. If a comment only makes sense to someone who
saw the old code, delete it.

Before keeping a comment, delete the code it annotates from view and ask: does the comment add anything the identifiers,
values, and types don't already say? If it just restates the line in English ("set X to true", "// import foo",
`singleQuote: true // use single quotes`), cut it. A comment earns its place only by supplying context not visible in
the code: a why, a constraint, a non-obvious consequence, a link.

## Pull requests

Keep PR descriptions **concise and reviewer-focused**: what changed, why, and anything reviewers need to know. Avoid
walls of text.

Default template (fill in only what's relevant, remove empty sections):

```markdown
**What**: [one-line summary of the change]

**Why**: [problem being solved or motivation]

**How**: [brief description of the approach, if unclear from the diff]

**Notes for reviewer**: [anything to pay attention to, risks, skipped alternatives]
```

## GitHub Interactions

Always use the `gh` CLI tool when interacting with GitHub (creating PRs, issues, checking status, etc.) rather than
using the API directly or other methods.

## Asking questions

Never set the `preview` field on `AskUserQuestion` options. It switches the UI to a side-by-side layout where option
labels are short and the descriptions are hidden, which is not enough context to choose confidently. Always use the
plain form: every option carries both a `label` and a `description`. Code snippets, mockups, and comparisons belong in
the message text instead.

## Tools

- use `fd` instead of `find`
- use `rg` instead of `grep`
- never install packages with `brew`; use `nix shell nixpkgs#<package>` for any missing tools
