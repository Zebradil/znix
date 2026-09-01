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
sops decrypt could supply it. CI therefore reads four repository secrets directly:

| Secret | Contents |
|---|---|
| `CACHE_PRIVATE_KEY` | the `signing-key` value from `secrets/cache.yaml` |
| `CACHE_URL` | the bucket part of `cache-s3-url`; workflows wrap it as `s3://<value>` |
| `AWS_ACCESS_KEY_ID` | as in `secrets/cache.yaml` |
| `AWS_SECRET_ACCESS_KEY` | as in `secrets/cache.yaml` |

`secrets/cache.yaml` remains the source of truth for the local push and the place to change a value;
after editing it, mirror the change into the repository secrets with `gh secret set`.

## Rotating a cache credential

Edit `secrets/cache.yaml`, then push the same value to the matching repository secret:

```bash
sops secrets/cache.yaml
gh secret set CACHE_PRIVATE_KEY < /path/to/new-key   # or AWS_*, CACHE_URL
```
