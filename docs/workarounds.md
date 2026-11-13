# Workarounds

A **workaround** is a temporary change that makes up for something broken
upstream: a package that fails to build, a NixOS default that is wrong, a
certificate that should no longer be trusted. Every workaround is expected to
die. Each one declares how to tell that upstream is fixed. A scheduled probe
asks that question against the inputs the flake would move to next. When the
answer is yes, the probe opens a pull request that deletes the workaround.

The framework is a flake-parts module, `inputs.znix.flakeModules.workarounds`.
znix uses it, and so can any other flake. This document is the specification.
[ADR 0007](adr/0007-workarounds-framework.md) records why it looks this way.

## Terms

**Entry**
: One workaround, declared as `workarounds.<name>` in one file. `<name>` is
  unique within the flake and names its probe, its branch, and its removal PR.

**Kind**
: What an entry changes. `pin` and `override` change a package through the
  workarounds overlay. `module` adds configuration to NixOS, nix-darwin, or
  Home Manager configurations.

**Candidate inputs**
: The lock the flake would have after `nix flake update`. Probes judge the
  candidate, never only the current lock (see [Probing](#probing)).

**Probe**
: A derivation, `fixed`, that **builds only when the entry is no longer
  needed**. A build failure means "still needed", and that is the normal state.

**Probe pkgs**
: The package set a probe receives: candidate `nixpkgs`, imported with
  `allowUnfree`, plus every *other* entry's overlay. The entry being probed is
  left out, and nothing else is.

## Declaring an entry

One entry per file. The file holds everything the entry needs, including a pin's
flake input, so removal is a single `git rm`. The default location is
`modules/flake/workarounds/<name>.nix`; set `file` when it lives elsewhere.

### `override`: patch a package

```nix
_: {
  workarounds.tuxedo-drivers = {
    package = "linuxKernel.packages.linux_xanmod_latest.tuxedo-drivers";
    systems = [ "x86_64-linux" ];
    reason = "The Makefile re-passes $(MAKEFLAGS) unquoted, which breaks on the kernel's cmd_sign flag.";
    override = _pkgs: old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace Makefile --replace-fail ' $(MAKEFLAGS)' ""
      '';
    };
  };
}
```

`override` is `pkgs: old: attrs` and is passed to `overrideAttrs`.

### `pin`: take a package from another nixpkgs revision

```nix
_: {
  flake-file.inputs.nixpkgs-pin-mise.url = "github:NixOS/nixpkgs/<40-char sha>";

  workarounds.mise = {
    pin = "nixpkgs-pin-mise";
    reason = "mise fails to build in later revisions: missing cmake.";
  };
}
```

`pin` names a flake input. Use a commit SHA, not a branch, so that
`nix flake update` leaves the pin where it is. After adding one, run
`nix run .#write-flake` and `nix flake lock`.

### `module`: change system or home configuration

```nix
_: {
  workarounds.polkit-agent-helper-hidraw = {
    systems = [ "x86_64-linux" ];
    reason = "polkit-agent-helper@.service ships PrivateDevices=yes, so pam_u2f cannot reach /dev/hidraw*.";
    module.nixos = { lib, ... }: {
      systemd.services."polkit-agent-helper@".serviceConfig.PrivateDevices = lib.mkForce false;
    };
    fixed = pkgs: pkgs.runCommand "polkit-agent-helper-allows-hidraw" { } ''
      if grep -q '^PrivateDevices=yes' ${pkgs.polkit.out}/lib/systemd/system/polkit-agent-helper@.service; then
        exit 1
      fi
      touch $out
    '';
  };
}
```

`module` is an attribute set keyed by module class (`nixos`, `darwin`,
`homeManager`). Each value is an ordinary module. A `module` entry must set
`fixed`, because "it builds" says nothing about configuration.

Write probes so that a failing command fails the build. The builder runs with
`set -e`, but `set -e` ignores a command negated with `!`, so
`! grep -q …` never fails. Use `if … then exit 1; fi`.

### Options

| option | default | meaning |
| --- | --- | --- |
| `reason` | required | One line on what is broken upstream. It is quoted in the removal PR. |
| `systems` | `null` | Systems the breakage affects. `null` means every system in the flake's `systems`. For `module` entries it only selects where the probe runs (see [Wiring](#wiring)). |
| `package` | the entry name | Attribute path that a `pin` or `override` replaces, as in `dictdDBs.eng2rus`. |
| `pin` | `null` | Flake input that holds a nixpkgs revision where the package works. |
| `override` | `null` | `pkgs: old: attrs` for `overrideAttrs`. |
| `module` | `{ }` | Modules keyed by class: `nixos`, `darwin`, `homeManager`. |
| `fixed` | see below | `pkgs: drv`, the probe. It receives the probe pkgs. |
| `file` | `modules/flake/workarounds/<name>.nix` | Repo-relative path that the removal PR deletes. |

Rules, checked by `nix flake check`:

- An entry sets exactly one of `pin`, `override`, or a non-empty `module`.
- `package` is used only with `pin` or `override`.
- A `module` entry sets `fixed`.
- A package takes at most one `pin`.

### Several entries on one package

A package can carry more than one entry, each with its own name and the same
`package`. They stack in a fixed order. The pin, if any, chooses the base, and
then every override folds on top in name order. Each entry is probed and removed
on its own.

### Default probe

For `pin` and `override`, `fixed` defaults to building `package` from the probe
pkgs: the package as every host would get it if this entry were deleted today.
Set `fixed` explicitly when the breakage happens at runtime and a successful
build does not prove the fix. The function receives the probe pkgs, so the
unpatched package is `lib.getAttrFromPath (lib.splitString "." package) pkgs`.

## Wiring

The module adds these outputs to the flake:

| output | what it is |
| --- | --- |
| `overlays.workarounds` | Every `pin` and `override` that applies to the host platform. |
| `modules.nixos.workarounds` | Every `module.nixos` fragment. |
| `modules.darwin.workarounds` | Every `module.darwin` fragment. |
| `modules.homeManager.workarounds` | Every `module.homeManager` fragment. |
| `workarounds.registry` | Plain data for CI: name, kind, systems, file, reason. |
| `workarounds.probes.<system>.<name>` | The probe derivations. |
| `apps.<system>.workarounds` | The CI tool (see [Probing](#probing)). |
| `checks.<system>.workarounds` | Validates every entry and runs the tool's self-test. |

A consuming flake applies the overlay wherever it builds pkgs and imports the
class modules into every configuration. The framework does not do this itself.
It cannot know which of a flake's configurations share a pkgs instance, and an
overlay applied twice would apply every override twice.

A `module` fragment applies wherever its class module is imported; `systems`
does not gate it. Gating would need `pkgs` inside `lib.mkIf`, and that recurses
for any fragment that sets `nixpkgs.*`. A fragment that must differ by platform
checks `pkgs.stdenv.hostPlatform` itself, and one that depends on another
module's option reads it with `or`, since not every configuration imports that
module.

### Adopting it in another flake

1. Import the module: `imports = [ inputs.znix.flakeModules.workarounds ];`.
2. Add `overlays.workarounds` to every pkgs the flake builds, once.
3. Import `modules.<class>.workarounds` into every configuration of that class.

   A flake that builds its configurations with znix's `lib.mkNixos`,
   `lib.mkDarwin`, or `lib.mkHomeManager` gets steps 2 and 3 by passing
   `flake = inputs.self`. `mkHomeManager` adds only the overlay; the flake's
   own homeManager modules, `workarounds` among them, come in through
   `extraModules`.
4. Copy `.github/workflows/workarounds.yaml` and adjust the runner mapping, the
   Nix setup, the cache, and the token to the repository.

## Probing

The probe runs on a schedule, weekly by default, as a workflow in the consuming
repository. Its logic lives in `nix run .#workarounds`, so the workflow itself
is thin: each repository keeps its own runners, Nix setup, cache, and token.

1. **Candidate**: run `nix flake update` in a clean checkout and publish the
   resulting `flake.lock`. Every later step uses this one lock.
2. **`matrix`**: emit one `(name, system, runner)` job per entry and claimed
   system, given a `system:runner` mapping. A claimed system with no runner gets
   a warning. Its verdict is missing, so the entry can never be removed until a
   runner exists.
3. **`probe <name> <system> <dir>`**: build
   `workarounds.probes.<system>.<name>` and write the verdict
   `<dir>/<name>__<system>.json` as `{name, system, ok, paths}`. A failed build
   is the expected result and exits 0. `paths` lists what a successful probe
   built, for pushing to a cache.
4. **`propose <dir>`**: for each entry:
   - If every claimed system returned `ok`, rebuild
     `automation/drop-workaround-<name>` from the default branch: commit the
     candidate lock, delete `file`, run `nix run .#write-flake` when the flake
     has that app, run `nix flake lock`, and commit again. Force-push, and open
     the PR if none is open.
   - Otherwise, close any open removal PR for that entry and delete its branch.

### Why the candidate lock

A workaround often breaks once upstream fixes the problem it works around.
`substituteInPlace --replace-fail` fails when the text is gone. A blocklist
entry naming a certificate fails when the bundle no longer has it. On that day
the regular lock-update PR goes red, the default branch keeps its old lock, and
a probe of the old lock reports "still needed" forever. Probing the candidate
lock, and carrying that lock in the removal PR, breaks the cycle: the removal PR
is the lock update that works.

### Pull requests

- Nothing is merged automatically. The probe proves that upstream is fixed. CI
  on the PR proves that every configuration still builds with the candidate
  lock and without the entry.
- A PR pushed with `GITHUB_TOKEN` starts no CI. The tool reads `HAS_APP_TOKEN`
  and, when it is not `true`, puts a warning at the top of the PR body.
- One branch per entry. Two entries that become removable in the same run get
  two PRs, and each carries the same candidate lock.

## Adding an entry: checklist

1. Write the file and `git add` it, because Nix ignores untracked files.
2. For a pin: `nix run .#write-flake` and `nix flake lock`.
3. `nix flake check`.
4. Build the probe. It must **fail**. If it succeeds, the workaround is not
   needed:

   ```bash
   nix build .#workarounds.probes.<system>.<name>
   ```

## Not a workaround

- Permanent additions, such as extra packages or overlays from other flakes.
  These are never probed.
- A change with no derivation that can tell "fixed" from "broken": a runtime
  race, or hardware behaviour. Keep it as a commented change in the module that
  owns it, with a link to the upstream issue.

## Limitations

- A probe answers whatever its derivation answers. A default probe proves that
  the package builds, nothing more.
- Probes substitute like any build. A probe target already cached upstream
  reports success without compiling.
- The probe pkgs come from the input named `nixpkgs`. A configuration built
  from a different nixpkgs input is not probed separately.
- Each pin instantiates its own nixpkgs. The store deduplicates shared paths.
