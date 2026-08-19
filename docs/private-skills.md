# Private skills (skillsync)

Company/internal skill repos (e.g. `trivago/platform-sre-skills`) cannot be referenced from this public repo — not
as flake inputs, not in `vendir.yml`, not vendored. `skillsync` bridges that gap: a standalone tool, packaged here
(`modules/home/skillsync.nix`), whose configuration lives entirely outside the repo.

## How it works

- Config: hand-written `~/.config/skillsync/config.yaml`. Its presence is the per-host gate — the tool is installed
  everywhere Claude profiles are enabled, but does nothing without a config. Private repo URLs appear only in this
  file, never in the repo.
- Clones: bare-minimum git clones under `~/.local/share/skillsync/clones/<source>/`, tracking a branch (default
  `main`). Treated as a tool-owned cache (`reset --hard` on update).
- Links: each included skill bundle is symlinked into every target directory (the skills dirs of the harnesses that
  should see it). skillsync only ever touches symlinks that point into its own clones dir; nix-managed store links
  and manual entries are left alone. Removing a source or an include prunes the corresponding links and clones,
  with confirmation.

No nix rebuild is needed for any skill change — edit the config, run `skillsync apply`.

## Commands

```bash
skillsync status              # configured/applied refs, remote updates, clone revs + links
skillsync diff [source]       # fetch and show incoming commits + diff
skillsync apply [-y] [source] # update clone(s), (re)link bundles, prune stale
```

`diff` before `apply` is the intended review flow. `apply <source>` updates one clone but linking/pruning always
works from the full config, so per-source applies never disturb other sources.

## Example config

```yaml
# ~/.config/skillsync/config.yaml — exists only on hosts that get private skills.
# Target dirs mirror the harness layouts defined in modules/home/{claude,opencode,cursor}*;
# personal Claude profile is excluded on purpose.
targets:
  - ~/.config/trv-claude/skills
  - ~/.config/trv-claude-key/skills
  - ~/.config/opencode/skills
  - ~/.cursor/skills
sources:
  platform-sre-skills:
    url: git@github.com:trivago/platform-sre-skills.git
    ref: main # optional, default main
    include: # explicit allowlist of skill bundles (top-level dirs with SKILL.md)
      - golang-sre
      - pr-message
      - setup-nix-flake
```

## Constraints

- A skill bundle name may be included by at most one source (they share a flat namespace in each skills dir).
- `ref` must be a branch or tag (`git clone --branch`); pinning to a commit is unsupported by design — sources
  track their branch, and `apply` is the manual moment of update.
- Git auth is ambient (ssh agent / gh credentials); skillsync does no credential handling.
