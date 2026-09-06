# Binary Cache Publishing

The `znix.zebradil.dev` S3 binary cache is populated by **CI** on every build, and can be
populated **manually** from a local machine with a single command. Both paths share one
implementation and one set of secrets (`secrets/cache.yaml`).

The implementation lives in **kasha**, not here: `kasha-cache-push` (resolve → sign → push,
then emit the generation manifest) ships as `packages.kasha-cache-push` from the pinned
`kasha` flake input, re-exported under the same attr by `modules/flake/kasha.nix`. It is the same
input that provides `kasha emit`, so the push and the manifest format it produces cannot
drift apart. Fixes arrive here through a `flake.lock` bump.

## Secrets

`secrets/cache.yaml` (sops-encrypted) holds everything needed to publish:

| Key | Contents |
|-----|----------|
| `cache-s3-url` | `s3://<bucket>?region=<region>` target for `nix copy --to` |
| `signing-key` | Nix signing private key matching `znix.zebradil.dev:nvr0OQFRddbHGopQbyLbLXQnntFBDKp23tqQq+msppw=` |
| `aws-access-key-id` | AWS access key for the bucket |
| `aws-secret-access-key` | AWS secret key for the bucket |

Edit the values with:

```bash
sops secrets/cache.yaml
```

The file is encrypted to two recipients (see `.sops.yaml`):

- `zebradil` — your personal age key, used for local pushes.
- `github-ci` — a dedicated age key, kept as a recipient for the moment but no longer used: CI
  reads the four values as repository secrets (see [CI credentials](#ci-credentials)). Its
  private key is the now-unused `SOPS_AGE_KEY` repository secret.

## Local push

Run from a checkout of this flake:

```bash
# Publish specific built attrs (output closure + the .drv recipe closure, valid paths only)
nix run .#cache-push -- checks.aarch64-darwin.trv4250-build

# No args: publish every checks.<current-system>.* output
nix run .#cache-push
```

`cache-push` decrypts `secrets/cache.yaml` with your personal age key, then hands off to
`kasha-cache-push`. Partial builds are fine — only store-valid paths are published.

## Compression

Nix compresses each NAR at push time and the **downloading side decompresses
it** — the cache only ever serves bytes. The work lands in whichever process
performs the substitution, which on a normal multi-user install is
**`nix-daemon`**, not the `nix` client: sampling CPU through a 28 s `nix-store
--realise` of an already-evaluated derivation gave 62 samples of `nix-daemon`
above 15 % and none of anything else. (The client shows up too if you sample a
`nix build` — that is evaluation, not decompression. For a `nix copy` between
two non-daemon stores there is no daemon and the `nix` process does it.)

That decompression is **single-threaded per NAR**, and on a fast LAN it, not
the link, is what limits a build.

Measured on tuxedo (20 threads, Determinate Nix 3.22.2 / 2.35.2), one 1.14 GB
NAR, `nix copy` from a local `file://` cache into a fresh empty store — so the
restore number is decompress + write with no network in it. Two passes, both
shown:

| store URI query | NAR size | restore | restore CPU | push | push CPU |
|---|---|---|---|---|---|
| `compression=xz` (Nix's default) | 237 MB | **7.42 s / 7.14 s** | 98 % | 179 s | 99 % |
| `compression=xz&parallel-compression=true` | 241 MB | 7.25 s / 7.25 s | 99 % | 23 s | 1694 % |
| `compression=zstd` | 325 MB | **1.62 s / 1.62 s** | 96 % | 2.4 s | 154 % |
| `compression=zstd&compression-level=10` | 296 MB | 1.83 s / 1.61 s | 96 % | 12.8 s | 103 % |

zstd restores **4.4x faster** and pushes **14-75x faster**. The restore-CPU
column is the whole story: every row pins exactly one core. (Push times were
taken with another job on the box, so read them as ratios, not benchmarks; the
restore times are clean.)

For scale, the LAN cache serves that NAR at 87-99 MB/s (~750 Mbit), so the xz
NAR arrives in ~2.5 s and then sits ~7 s in the decompressor. **That is where
"nix build downloads are slow, under 300 Mbit" comes from**: 237 MB through
`xz -d` in 6.1 s is 37 MB/s ≈ 296 Mbit/s of compressed stream, and Nix counts
progress in compressed bytes, so the rate it prints *is* the decompressor's
rate. No link change can move it.

### `parallel-compression` does not fix it

xz can decode in parallel, but only across independent blocks, and a NAR Nix
wrote with default settings is a single block:

```
$ xz -lvv <nar>.xz
  Streams:  1
  Blocks:   1
```

`parallel-compression=true` does produce a multi-block stream — 48 blocks for
the NAR above — and the **`xz` CLI** decodes that in 0.68 s at ~1700 % CPU, a
9x speedup over its own 6.1 s single-threaded run. **Nix does not**: same file,
7.25 s at 99 % of one core, indistinguishable from the single-block file. Its
xz decoder is single-threaded and gets nothing from the block index (inferred
from the CPU figure, not from reading Nix's source). So `parallel-compression`
buys the pusher wall-clock and buys every puller nothing — not worth the 1.4 %
size penalty on its own.

On the push side it works exactly as advertised — 1694 % CPU, 179 s down to
23 s — which is why it looks tempting. It just does not reach the client. It
also does not parallelise zstd: `compression-level=10` pushed at 103 %, one
core.

Changing the *format* is the only lever that reaches clients. zstd costs 25-37 %
more bytes and pays that back several times over: on the LAN, +0.9 s of transfer
for −5.5 s of decompression; on the 300 Mbit WAN path to R2 it is still ahead
(≈12.6 s → ≈9.9 s end to end). `compression-level=10` recovers a third of the
size penalty for free — same restore time, and still 14x cheaper to push than
xz.

### Choosing the level

A second sweep on tuxedo (AMD Ryzen AI 9 365, 20 threads, Determinate Nix
3.22.3) took three NARs spanning the compressibility range through every zstd
level. One NAR per timed run: the closure minus the target is seeded into the
cache first, untimed, so no measurement is diluted by its dependencies.

| rustc 1.95.0, 1059 MB raw | xz | zstd:1 | zstd:6 | zstd:9 | zstd:12 | zstd:19 |
|---|---|---|---|---|---|---|
| NAR | 221 MB | 353 MB | 301 MB | 291 MB | 289 MB | 254 MB |
| push | 205.7 s | 1.5 s | 4.3 s | 9.9 s | 20.1 s | 185.9 s |
| restore | 6.68 s | 1.49 s | 1.52 s | 1.48 s | 1.47 s | 1.73 s |

**Restore time is flat across every zstd level** — decompression speed is a
property of the format, not the level — so a higher level costs push time and
returns nothing to the machines substituting from the cache. Level 6 is the
knee: 12 is 1 % smaller for twice the push, and 19 costs as much as xz while
still landing 15 % larger than it.

`linux-firmware`, whose payload is already compressed, settles it: xz burns
249 s there to shave 1.6 %, and zstd:19 spends 102 s to shave 1.1 % over
zstd:1. A NixOS closure carries a lot of content like that.

### Where it is set

`compression` and `compression-level` are `BinaryCacheStore` settings, so they
travel only as query parameters on the store URI — `--option compression zstd`
is silently ignored. Nothing in this repo has to set them: both publishers
append `compression=zstd&compression-level=6` themselves.

- **CI** — nix-ci's `build` and `update-lock-pr` actions append it to
  `cache-s3-url`; override with their `store-params` input
- **local push** — `kasha-cache-push` appends it to `CACHE_S3_URL`; override
  with `CACHE_STORE_PARAMS`

Either one leaves a URL that names a `compression` of its own untouched, so the
`cache-s3-url` key in `secrets/cache.yaml` and the `CACHE_S3_URL` repository
variable both stay bare bucket URLs.

Existing NARs stay xz; only new pushes change. The two formats coexist in one
bucket because each `.narinfo` names its own `URL:` and `Compression:`, so there
is no migration and no flag day. `nix copy` asks the remote what it already has,
so a published path only converts when it is rebuilt — or when its `.narinfo`
and NAR are deleted from the bucket and re-pushed.

## CI

CI lives in **[nix-ci](https://github.com/zebradil/nix-ci)**, a separate repo of reusable GitHub
Actions workflows and composite actions. `.github/workflows/{test,update,update-pr}.yaml` are thin
callers of its actions:

| Action | Role |
|---|---|
| `setup-nix@v1` | installs Nix, adds `znix.zebradil.dev` as a substituter, and registers the signing key as nix.conf `secret-key-files` so every path the runner builds is signed as it is produced |
| `discover@v1` | enumerates `checks.*` into a build matrix |
| `build@v1` | builds one attr with `strategy: uncached-leaves` and pushes the closure plus the toplevel's `.drv` recipe; exposes `paths-file` |
| `update-lock-pr@v1` | the nightly `nix flake update` PR, with the nvd diff and the post-update push |

`zebradil/kasha/.github/actions/emit-manifest@v1` is chained after each push to write the
`roots/znix/<gen>.json` generation manifest. That step is why these workflows call the actions
directly instead of nix-ci's `ci.yaml` / `update-pr.yaml` wrapper workflows: a wrapper forwards no
outputs, so it cannot hand `paths-file` to the manifest step, and an unrooted NAR is deleted by the
nightly kasha GC sweep.

### CI credentials

nix-ci has no sops mode: it takes the signing key, S3 URL and AWS credentials as plain inputs. A
reusable workflow cannot receive secrets produced by a step, and `setup-nix` needs the signing key
*before* Nix exists (it goes into the installer's nix.conf), so there is no point in the run where a
sops decrypt could supply it. CI therefore reads three repository secrets and one variable directly:

| Name | Kind | Contents |
|---|---|---|
| `CACHE_PRIVATE_KEY` | secret | the `signing-key` value from `secrets/cache.yaml` |
| `AWS_ACCESS_KEY_ID` | secret | as in `secrets/cache.yaml` |
| `AWS_SECRET_ACCESS_KEY` | secret | as in `secrets/cache.yaml` |
| `CACHE_S3_URL` | variable | `cache-s3-url` verbatim, `s3://` scheme included |

`CACHE_S3_URL` is a variable, not a secret: it is a bucket name and an endpoint,
and writing to it takes the AWS credentials, which are secrets. As a variable it
stays readable after it is set, survives review, and is available to fork pull
requests — where the push is gated off anyway by `PUSH_TO_CACHE`.

`secrets/cache.yaml` remains the source of truth for the local push and the place to change a value;
after editing it, mirror the change into the repository secrets with `gh secret set`.

## Rotating a cache credential

Edit `secrets/cache.yaml`, then push the same value to the matching repository secret:

```bash
sops secrets/cache.yaml
gh secret set CACHE_PRIVATE_KEY < /path/to/new-key   # or AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
gh variable set CACHE_S3_URL --body "$(sops decrypt --extract '["cache-s3-url"]' secrets/cache.yaml)"
```
