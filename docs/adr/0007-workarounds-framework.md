# A workarounds framework shared across flakes

Status: accepted. Supersedes [ADR 0004](0004-workaround-probes.md).

ADR 0004 made removal of package workarounds automatic. The mechanism then grew
one case at a time: `check` for runtime breakage, leave-one-out after the `mise`
misfire, `extend` handling for kernel package sets. It never gained a way to
express a workaround that is configuration rather than a package, so the
polkit `PrivateDevices` override and similar changes stayed inline, invisible to
the probe. Other flakes need the same thing and have nothing.

We redesign from a written specification, [`docs/workarounds.md`](../workarounds.md),
and ship it as `flakeModules.workarounds` so that every flake runs the same code.

## Decisions

**Every entry has one probe contract.** `fixed` is a derivation that builds only
when the entry is no longer needed. Package kinds get a default (build the
package without this entry). Module kinds must supply one. ADR 0004 had two
contracts under one name: "the package builds" and "`check` builds".

**Configuration is a first-class kind.** `module.<class>` carries NixOS,
nix-darwin, or Home Manager fragments, exported as `modules.<class>.workarounds`.

**Probes judge the candidate lock.** A workaround frequently breaks on the same
upstream change that makes it unnecessary: `--replace-fail` loses its target, a
certificate blocklist names a root the bundle dropped. The regular lock update
then fails, the default branch keeps the old lock, and a probe of that lock
says "still needed" forever. The probe workflow runs `nix flake update` first,
and the removal PR carries that lock.

**Logic in a flake app, not in a shared workflow.** Consumers run CI on
different runners, caches, Nix setups, and tokens, and some restrict which
third-party workflows they may call. `nix run .#workarounds` holds every step;
each repository keeps a short workflow of its own.

**Validation reaches `nix flake check`.** ADR 0004 forced entry validation only
from the probe's `nix eval`, so a malformed entry surfaced a week late.
`checks.<system>.workarounds` forces the registry and runs the tool's
self-test.

**The framework does not apply its own overlay.** Consumers compose overlays
differently (znix folds it into `overlays.default`). Applying it from the class
modules as well would double-apply every override.

## Considered options

**Keep ADR 0004 and add a module kind.** Smallest diff, but it keeps two probe
contracts and the deadlock, and the code stays znix-private.

**A reusable `workflow_call` workflow.** One copy of the YAML, but it would bind
every consumer to this repo's runner labels and Nix setup action, and it fails
where an organisation allows only its own workflows.

**Probe both the current and the candidate lock.** It tells "fixed by the
pending update" apart from "already fixed". Rejected: either way the action is
the same, a removal PR on the candidate lock, and the second probe doubles the
cost.

## Consequences

- Option paths change from `znix.workarounds.<name>` to `workarounds.<name>`,
  and outputs from `workaroundProbes`/`workaroundRegistry` to
  `workarounds.{probes,registry}`.
- A removal PR is also a lock update. It can conflict with the regular
  lock-update PR. Whichever merges second is rebuilt on its next run.
- `nix flake check` warns about the unknown `workarounds` output. Harmless.
