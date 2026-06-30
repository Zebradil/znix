# Vendored AI Skills

External agent skills ([mattpocock/skills](https://github.com/mattpocock/skills),
[JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman)) are vendored
into the repo with [vendir](https://carvel.dev/vendir/) rather than pulled as
flake inputs. The synced files are committed, so every upstream update lands as a
reviewable diff instead of an opaque lock bump.

## Layout

```
vendir.yml            Declares sources, include/exclude paths
vendir.lock.yml       Pins the resolved commit SHA (do not edit by hand)
vendor/
  mattpocock-skills/
    engineering/<skill>/
    productivity/<skill>/
  caveman/                 not just skills — also hooks/plugins/rules/commands
    src/{hooks,plugins,rules}/
    skills/<skill>/
    commands/ agents/
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

`caveman` is consumed differently: `modules/home/{claude,opencode}/caveman.nix`
reference `inputs.self + "/vendor/caveman/..."` directly (hooks, the opencode
plugin, the activation ruleset and skills), not via `extraSkillRoots`.

`ponytail` (DietrichGebert/ponytail) mirrors that wiring in
`modules/home/{claude,opencode}/ponytail.nix`, gated on `znix.claude.ponytail`.
It targets minimal-code behaviour (orthogonal to caveman's terse prose), so both
can run at once. Its Claude hooks register `SessionStart`, `UserPromptSubmit` and
`SubagentStart` (see `mkPonytailHooks` in `claude/default.nix`), and the per-addon
statusline badges are stacked by `modules/home/claude/statusline.nix` rather than
by either addon. The opencode plugin (`.opencode/plugins/ponytail.mjs`) resolves
its siblings via realpath-relative requires, so the whole `vendor/ponytail`
subtree is vendored intact and only the `.mjs` is symlinked.

## Updating

```bash
nix develop                            # vendir is in the dev shell
vendir sync                            # re-resolves every source
vendir sync --directory vendor/caveman # or bump a single source
git add vendor vendir.lock.yml
```

`vendir sync` (no flag) re-resolves *all* sources, so a bare sync bumps every
pinned SHA. Use `--directory vendor/<name>` to update one source in isolation
and keep the others pinned.

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
