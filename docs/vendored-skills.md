# Vendored AI Skills

External agent skills (currently [mattpocock/skills](https://github.com/mattpocock/skills))
are vendored into the repo with [vendir](https://carvel.dev/vendir/) rather than
pulled as a flake input. The synced files are committed, so every upstream update
lands as a reviewable diff instead of an opaque lock bump.

## Layout

```
vendir.yml            Declares sources, include/exclude paths
vendir.lock.yml       Pins the resolved commit SHA (do not edit by hand)
vendor/
  mattpocock-skills/
    engineering/<skill>/
    productivity/<skill>/
```

## How it wires in

`vendir.yml` strips the upstream `skills/` prefix (`newRootPath`) so each skill
bundle lands directly under `engineering/` or `productivity/`. The
`znix.claude.extraSkillRoots` option (in `modules/home/claude/default.nix`)
defaults to those two directories. Both the Claude module (`mkExtraSkillFiles`)
and the opencode module symlink every bundle into each profile's `skills/`,
honouring per-profile `excludeAssets.skills`.

No `.nix` change is needed to add or drop a skill from an already-vendored
source — `vendir sync` rewrites the tree and the modules pick it up.

## Updating

```bash
nix develop                # vendir is in the dev shell
vendir sync                # re-resolves ref, rewrites files + vendir.lock.yml
git add vendor vendir.lock.yml
```

Review the resulting diff before committing — these are prompts that steer agent
behaviour, so changes are worth reading. New files must be staged before Nix
evaluates them (untracked files are invisible to flakes).

## Adding a source

Add a directory entry to `vendir.yml`. Use `includePaths` / `excludePaths` to
select what to vendor and `newRootPath` to flatten, then point a consumer at it
(e.g. extend `extraSkillRoots`). Example exclusions in the current config:

- `skills/engineering/setup-matt-pocock-skills/**` — a meta-installer that
  git-clones skills into `~/.claude`, incompatible with this declarative,
  read-only-symlink setup.
- `skills/**/README.md` — category docs, not skills.

## Verify

```bash
nix flake check
hmf=$(nix build '.#darwinConfigurations.<host>.config.home-manager.users.<user>.home-files' \
  --no-link --print-out-paths)
ls "$hmf/.config/personal-claude/skills"     # Claude
ls "$hmf/.config/opencode/skills"            # opencode
```
