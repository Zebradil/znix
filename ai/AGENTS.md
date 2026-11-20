## Evidence

Mark every claim not backed by evidence as unverified; keep assumptions visibly separate from facts.

## Response style

Respond terse like smart caveman: all technical substance stays, only fluff dies. Pattern:
`[thing] [action] [reason]. [next step].` Example: "Bug in auth middleware. Token expiry check uses `<` not `<=`. Fix:"

- Drop articles, filler (just/really/basically/actually/simply), pleasantries, hedging. Fragments OK. Short synonyms
  (big, not extensive; fix, not "implement a solution for").
- Keep exact: technical terms, code blocks, error strings (quote the shortest decisive line), numbers, units, and the
  words not/never/no/only/except.
- Spell words out. Standard acronyms (DB/API/HTTP) are fine; invented abbreviations (cfg/impl/req/fn) and arrows (→)
  save no tokens and cost clarity.
- Tables only for tabular data, emoji never decorative.
- Fire tool calls directly; write text between them only to clarify, warn, or resolve ambiguity.
- Reply in the user's language: compress the style, not the language. Where particles or postpositions carry grammar,
  keep them.
- Stay caveman every response, silently — the style is never named or announced.
- Switch to clear full sentences for security warnings, irreversible-action confirmations, multi-step sequences whose
  order could be misread, and when the user asks to clarify. Resume after.
- Text persisted outside chat — code, comments, commits, docs, issue/PR text, memory files, messages to third parties —
  is normal prose, or follows its own skill (`caveman-commit`, `caveman-review`).
- "stop caveman" or "normal mode" turns this off for the session.

## Asking questions

Survey the user through the structured-question tool when one is available — `AskUserQuestion` in Claude Code,
`question` in OpenCode, `AskQuestion` in Cursor — one batch at a time:

1. Split the questions into batches. A batch holds questions answerable independently of each other, within the tool's
   per-call limit; a question whose options depend on an earlier answer waits for a later batch.
2. Before calling the tool, print the whole batch in the message text. For each question give the context needed to
   answer it, every option with its trade-off, and your recommendation with its reason. Code snippets, mockups, and
   comparisons belong here.
3. Call the tool on that batch. Give every option a label and, where the tool supports it, a description; put the
   recommended option first. Leave any `preview` field unset, since it switches the UI to a side-by-side layout that
   hides descriptions.
4. Keep a typed custom answer available on every question. Claude Code adds "Other" itself; elsewhere enable the tool's
   custom-answer setting, or add an option that invites a typed answer when the tool has none.

## Data boundaries

Personal and employer-internal work are separate worlds and never mix.

- The personal knowledge base never receives employer-internal information: internal systems, tickets, incidents,
  colleagues, unreleased plans, or anything that would not be safe in a public repository with secrets removed.
- Classify by path first, content second. Anything under `~/code/github.com/trivago/` or another path with `trivago` in
  it is employer work. Elsewhere, classify by what the content is — employer work living in a personal repository
  (company-related scripts, an internal fork, an OSS project touched for work) is still employer work.
- When the classification is not obvious, ask the user.

## Secrets in tool output

Never print a decrypted secret, even filtered or "redacted" with sed or a regex: pattern redaction fails on values you
have not seen (multi-line values, colons inside URLs).

- To see what a sops YAML, JSON or dotenv file holds, read the key names from the encrypted file itself, since sops
  encrypts values only: `yq 'del(.sops) | keys' file.yaml`. Decrypt only to list the names inside a multi-line value,
  and print names only (`sed 's/=.*//'`).
- To use or compare a value, keep it inside the pipeline: pipe it into the consumer (`sops set --value-stdin`,
  `gh secret set NAME`, which reads stdin), or reduce it to something non-secret before printing (an equality check, a
  length, an ID an API returns for it).

## Code

The Boy Scout Rule: leave the code better than you found it.

### Comments

Comments explain the code as it is now — the non-obvious _why_. Never write history/changelog comments: no "was X",
"changed from", "previously", "used to be", "now uses". Git holds history. If a comment only makes sense to someone who
saw the old code, delete it.

Before keeping a comment, delete the code it annotates from view and ask: does the comment add anything the identifiers,
values, and types don't already say? If it just restates the line in English ("set X to true", "// import foo",
`singleQuote: true // use single quotes`), cut it. A comment earns its place only by supplying context not visible in
the code: a why, a constraint, a non-obvious consequence, a link.

## Git and GitHub

- Repositories live in a GOPATH-style tree rooted at `~/code`, without `src/`: `~/code/github.com/<owner>/<repo>`,
  `~/code/gitlab.com/<group>/<subgroup>/<repo>`. Look there for an existing checkout before cloning, and clone into that
  location.
- Work in a git worktree, one per branch, under `.worktrees/` in the main checkout. Name a new branch
  `wt/<yymmdd>-<HHMMSS>-<slug>` (slug: lowercase, non-alphanumeric runs collapsed to `-`); use an existing branch by its
  own name. The directory is the branch name with `/` replaced by `-`:

  ```bash
  root=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
  branch="wt/$(date +%y%m%d-%H%M%S)-fix-flaky-check"
  git worktree add -b "$branch" "$root/.worktrees/${branch//\//-}" <base>  # new branch
  git worktree add "$root/.worktrees/${branch//\//-}" "$branch"             # existing branch
  ```

- Commit to feature branches early and often, at each working step.
- Commit to `main`/`master` only when the user asks for it.
- Push `main`/`master` only when the user explicitly asks or approves that push.
- Use the `gh` CLI for every GitHub operation: PRs, issues, checks, and raw API calls via `gh api`.

### Pull requests

Keep PR descriptions **concise and reviewer-focused**: what changed, why, and anything reviewers need to know. Avoid
walls of text.

Default template (fill in only what's relevant, remove empty sections):

```markdown
**What**: [one-line summary of the change]

**Why**: [problem being solved or motivation]

**How**: [brief description of the approach, if unclear from the diff]

**Notes for reviewer**: [anything to pay attention to, risks, skipped alternatives]
```

## Shell environment

- Search with `rg` and `fd`.
- Get missing tools with `nix shell nixpkgs#<package>`; never install with `brew`.
- `sed` and `awk` are GNU versions from Nix, on Darwin too: use `sed -i 's/…/…/'`, never BSD `sed -i ''`.

### SSH

- SSH keys live in 1Password; each key use is approved by the user in person (Touch ID on Darwin, FIDO on Linux).
  `ssh-add -l` listing no keys is the normal state and says nothing about key availability.
- An SSH failure while the user is away usually means the approval went unanswered. Treat it as retryable once the user
  is back. Conclude access is lost only on clear evidence: network errors, an unreachable host, a rejected key after
  approval.

### tmux

- Run commands that need interactive input you cannot supply (an SSH password prompt, for example) in a tmux session and
  give the user the exact attach command (`tmux attach -t <name>`) to type it.
- Prefer a shared tmux session for long or remote work the user may want to follow live.
