## Code

The Boy Scout Rule: leave the code better than you found it.

## Code comments

Comments explain the code as it is now — the non-obvious _why_. Never write history/changelog comments: no "was X",
"changed from", "previously", "used to be", "now uses". Git holds history. If a comment only makes sense to someone who
saw the old code, delete it. Don't comment the obvious.

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

## Tools

- use `fd` instead of `find`
- use `rg` instead of `grep`
- never install packages with `brew`; use `nix shell nixpkgs#<package>` for any missing tools
