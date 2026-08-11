## General

If your statement is not supported by any evidence, mark it as such. Avoid presenting assumptions as facts.

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
