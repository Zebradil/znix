# Probing workarounds for removal

Status: accepted

Packages broken in `nixpkgs-unstable` get worked around here — pinned to an
older revision, or patched with `overrideAttrs`. Every one is meant to be
temporary, and none of them were. The `mise` pin, the `lld` link override for
`keepassxc`/`moonlight-qt`: at the time of writing, vanilla nixpkgs already
builds all three, and nobody noticed because noticing required remembering to
check. The override ones cost real time too — an `overrideAttrs` changes the
derivation hash, so a workaround that outlives its cause turns a cache hit into
a local Qt build.

We make removal automatic. `modules/flake/workarounds/<package>.nix` declares one
workaround per file, and a weekly workflow builds each affected package from
**vanilla nixpkgs, no overlays**. A build that succeeds means upstream is fixed;
the workflow deletes the file, regenerates the flake and lock, and opens a
removal PR.

## The pass condition is a failure

The probe is inverted relative to every other check in this repo: the healthy
steady state is a *failed* build. That drives three things.

Probes live in their own `flake.workaroundProbes` output rather than in `checks`,
so `discover-targets.sh` never sweeps them into the build matrix, where a
"failing" probe would turn main red. The probe workflow is standalone rather than
a mode of `nix-ci.yaml`, because that workflow is consumed by other repos via
`uses:` and an inverted pass/fail semantic has no business propagating there. And
the build step tolerates failure explicitly instead of using `continue-on-error`,
which would still mark the run as degraded.

Probes import nixpkgs with `allowUnfree`. Without it an unfree package such as
`obsidian` fails the licence check, and a licence failure is indistinguishable
from a build failure — the probe would report "still needed" forever.

## Considered Options

**Cache probe instead of a build.** Evaluate the vanilla output path and query
`cache.nixos.org` for its `.narinfo`; a 200 means hydra built that exact
derivation. Nearly free, and the repo already has `probe-cache.sh`. Rejected:
hydra never builds unfree packages, so `obsidian` would be permanently invisible,
and a cache miss conflates "broken", "hydra lagging" and "unfree" into one
answer. A `nix build` with substituters enabled is cheap in exactly the cases the
narinfo probe would have been cheap, and correct in the ones it would not.

**Report an issue instead of a PR.** Trivial to build, but the mise pin proves
what happens to a nag: nothing. A PR is also self-validating — the probe proves
the package builds, the CI matrix on the PR proves the hosts do.

**Auto-merge the removal PR.** Consistent with the nightly lock update, and safe
for every workaround we have today, since all of them mask *build-time*
breakage that CI would catch. Rejected because that safety is a property of the
current set, not a guarantee: a workaround patching runtime behaviour would pass
CI green and break on the host. Review is cheap at a handful of PRs a year.

**One registry list in `overlays.nix`.** Rejected once removal had to be
mechanical: deleting an entry from a list means editing Nix source around
comments and formatting. One file per workaround makes removal `git rm`, which
also matches the dendritic pattern the rest of the repo uses. `flake-file.inputs`
is already declared per-module, so a pin's input lives in the same file as the
pin.

## Consequences

- The probe answers "does it build?", not "does it work?". A runtime-shaped
  workaround needs its own check; whoever adds one owns that.
- A workaround is removed only when it builds on **all** the systems it claims.
  Partial fixes keep the workaround and produce no PR, rather than a red one.
- `nix flake check` warns about the unknown `workaroundProbes` output. Harmless.

## Amendment: probes leave one out

"Vanilla nixpkgs, no overlays" was too blunt, and `mise` showed why. It carried
two independent workarounds — `doCheck = false` for a test that fails on Darwin,
and a pin — but only the pin was declared as one; the other sat in
`modules/home/mise.nix` as an `overrideAttrs` on `programs.mise.package`. The
probe therefore built a package no host builds: plain `mise`, which hydra had
already cached, so the probe "succeeded" without compiling anything and opened a
removal PR that CI immediately failed.

A probe now builds its package with every **other** workaround still applied,
and drops only its own. For a package with one workaround that is the vanilla
build as before; for `mise` it asks the two questions that actually matter —
does the Darwin test pass yet, and has nixpkgs moved cmake out of
`nativeCheckInputs`. Several workarounds may therefore target one package
(`package` names the attribute, the entry name stays unique), and they compose
in a fixed order: the pin picks the base, overrides fold on top in name order.

The corollary is a rule: a package modification that is temporary belongs in
`modules/flake/workarounds/`, never inline in the module that consumes it. An
inline override is invisible to the probe, and it makes the probe lie about the
workarounds that *are* declared.

## Amendment: CI moved out of this repo

The reusable workflows this ADR contrasts the probe against — `nix-ci.yaml`,
`discover-targets.sh`, `probe-cache.sh` — now live in
[zebradil/nix-ci](https://github.com/zebradil/nix-ci); this repo only calls
them. Nothing above changes: probes still sit in `flake.workaroundProbes` so
nix-ci's `discover` action never sweeps them into the build matrix, and
`workaround-probe.yaml` is still standalone, now for the additional reason that
its inverted pass condition has no place in a shared CI repo.
