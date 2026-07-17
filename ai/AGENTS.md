## Code comments

Comments explain the code as it is now — the non-obvious _why_. Never write history/changelog comments: no "was X",
"changed from", "previously", "used to be", "now uses". Git holds history. If a comment only makes sense to someone who
saw the old code, delete it. Don't comment the obvious.

## GitHub Interactions

Always use the `gh` CLI tool when interacting with GitHub (creating PRs, issues, checking status, etc.) rather than
using the API directly or other methods.

## Tools

- use `fd` instead of `find`
- use `rg` instead of `grep`
- never install packages with `brew`; use `nix shell nixpkgs#<package>` for any missing tools
