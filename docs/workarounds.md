# Workarounds

A **workaround** replaces a package that is broken in `nixpkgs-unstable` with
one that works, until upstream catches up. Every workaround is temporary by
definition — a weekly probe checks whether it can go, and opens the removal PR
itself.

Two kinds:

- **pin** — take the package from a nixpkgs revision where it still builds.
- **override** — keep the current package but patch its derivation.

Permanent additions (tree-sitter grammars, `gke-kubeconfiger`) are not
workarounds. They live directly in `modules/flake/overlays.nix` and are never
probed.

A temporary package modification belongs here even when it is a one-line
`overrideAttrs` — never inline in the module that consumes the package. Inline
overrides are invisible to the probe, and they make the probe lie about the
workarounds that *are* declared: it builds a package no host builds.

## Adding a workaround

One file per workaround, at `modules/flake/workarounds/<name>.nix`. It holds
everything that workaround needs — including its flake input, if it is a pin —
so removing it is a single file deletion.

A pin:

```nix
{ ... }:
{
  flake-file.inputs.nixpkgs-pin-mise.url = "github:NixOS/nixpkgs/9bc0289...";

  znix.workarounds.mise = {
    pin = "nixpkgs-pin-mise";
    reason = "mise fails to build in later nixpkgs revisions: missing cmake.";
  };
}
```

An override:

```nix
{ ... }:
{
  znix.workarounds.keepassxc = {
    systems = [ "aarch64-darwin" ];
    reason = "ld64-957.1 SIGTRAPs linking large Qt apps; link with LLVM lld instead.";
    override = pkgs: old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.lld ];
    };
  };
}
```

Options (see `modules/flake/workarounds.nix` for the full set):

| option | default | meaning |
| --- | --- | --- |
| `package` | the attribute name | nixpkgs attribute being replaced; may be nested one level, as in `dictdDBs.eng2rus` |
| `systems` | `null` (all) | systems the breakage affects |
| `reason` | required | one line, quoted in the removal PR |
| `pin` | `null` | flake input holding a working nixpkgs revision |
| `override` | `null` | `pkgs: old: attrs`, passed to `overrideAttrs` |

Set exactly one of `pin` / `override`.

## Several workarounds on one package

A package can carry more than one, each in its own file with its own name and
`package` pointing at the shared attribute — `mise` needs `mise-darwin-tests` to
skip a test that fails on Darwin, and `mise-cmake` to put back the cmake that
skipping drags out of `nativeCheckInputs`. They stack in a fixed order: the pin
(at most one per package) chooses the base, then every override folds on top in
name order. Each is probed and removed on its own.

For a pin, use a specific 40-char commit SHA rather than a branch, so the lock
stays reproducible. Find one by browsing the package's nixpkgs history:

```
https://github.com/NixOS/nixpkgs/commits/master/pkgs/by-name/nu/nushell/package.nix
```

## Regenerate and lock

New `.nix` files must be staged before Nix evaluates them (edits to existing
files don't need this):

```bash
git add modules/flake/workarounds/<name>.nix
nix run .#write-flake   # regenerates flake.nix — only needed for a pin
nix flake lock          # pulls in the pinned nixpkgs
```

## Verify

```bash
nix flake check --no-build
nix build .#darwinConfigurations.<host>.pkgs.<package>
```

To confirm a per-system workaround is NOT applied elsewhere, compare the
overlaid derivation against its probe — these two should differ on an affected
system and match on an unaffected one:

```bash
nix eval .#nixosConfigurations.<host>.pkgs.<package>.drvPath
nix eval .#workaroundProbes.<system>.<name>.drvPath
```

Probes are keyed by workaround `<name>` — the attribute under
`znix.workarounds` — which is the same as `<package>` unless the entry sets
`package` explicitly.

The probe is expected to *fail* while the workaround is still needed, so build
it by hand after adding one. If it succeeds, the workaround is already dead:

```bash
nix build .#workaroundProbes.<system>.<name>
```

## Removal

`.github/workflows/workaround-probe.yaml` runs every Monday (and on manual
dispatch). For each workaround it builds `#workaroundProbes.<system>.<name>` on
every system the workaround claims: the package from vanilla `nixpkgs` with
every *other* workaround on it still applied, and only this one dropped. For a
package carrying a single workaround that is the plain upstream build. A claimed system with no CI runner is warned about and
skipped; since a missing verdict counts as "still broken", such a workaround is
never proposed for removal.

A build that **succeeds** is the alarm: upstream is fixed. When every system
succeeds, the workflow deletes the file, regenerates `flake.nix` and
`flake.lock`, and opens `automation/drop-workaround-<name>` for review. Nothing
is merged automatically — the probe proves the *package* builds, and CI on the
PR proves the *hosts* still do.

Successful probe builds are pushed to the binary cache, since the vanilla path
is what every host pulls the moment the workaround is dropped.

If a workaround regresses upstream while its removal PR is open, the next probe
closes that PR and deletes the branch.

To remove one by hand: delete the file, then `nix run .#write-flake` and
`nix flake lock`.

## Limitations

- The probe answers "does it build?", not "does it work?". A workaround that
  patches *runtime* behaviour would be reported as removable while still being
  needed — see `docs/adr/0004-workaround-probes.md`.
- Each pin instantiates a separate nixpkgs; Nix deduplicates store paths, so the
  overhead is minor for temporary use.
- One package takes at most one pin, so it cannot be pinned to different
  revisions on different systems.
- Probes substitute like any other build, so a probe target that hydra has
  already cached reports success without compiling. That is usually right — it
  is the same binary the hosts would pull — but it means a probe cannot catch a
  package that only fails to build locally.
