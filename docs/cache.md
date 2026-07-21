# Binary Cache Publishing

The `znix.zebradil.dev` S3 binary cache is populated by **CI** on every build, and can be
populated **manually** from a local machine with a single command. Both paths share one
implementation (`.github/scripts/populate-nix-cache.sh`: resolve → sign → push) and one set
of secrets (`secrets/cache.yaml`).

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
- `github-ci` — a dedicated age key, used by CI. Its **private** key is stored as the
  `SOPS_AGE_KEY` GitHub Actions repository secret.

## Local push

Run from a checkout of this flake:

```bash
# Publish specific built attrs (output closure + the .drv recipe closure, valid paths only)
nix run .#cache-push -- checks.aarch64-darwin.trv4250-build

# No args: publish every checks.<current-system>.* output
nix run .#cache-push
```

`cache-push` decrypts `secrets/cache.yaml` with your personal age key, then signs and pushes
via the shared core script. Partial builds are fine — only store-valid paths are published.

## CI

Workflows `.github/workflows/{test,update}.yaml` pass `SOPS_AGE_KEY` into the reusable
`nix-ci` / `nix-update` workflows. Each build job:

1. Resolves the built store paths for its matrix attr.
2. `decrypt-cache-secrets` action: resolves the publishing credentials (see below).
3. `push-nix-cache` action: signs and pushes via `populate-nix-cache.sh --paths-file`.

### Two ways to supply CI credentials

The reusable workflows accept the cache credentials through **either** source — pick whichever
suits the consuming repo. The `decrypt-cache-secrets` action handles both:

1. **sops mode (single secret)** — set the `sops-age-key` workflow secret. The action decrypts
   `secrets/cache.yaml` from the repo with that age key. This is what znix itself uses
   (`SOPS_AGE_KEY`).
2. **direct mode (individual secrets)** — leave `sops-age-key` empty and instead pass the four
   `cache-signing-key`, `cache-s3-url`, `aws-access-key-id`, `aws-secret-access-key` workflow
   secrets straight in. No sops file needed. Convenient for other repos consuming these
   reusable workflows that don't want to adopt sops.

When `sops-age-key` is set it takes precedence and the direct secrets are ignored. When neither
is supplied, the publish step is a no-op.

Example caller using direct mode:

```yaml
jobs:
  ci:
    uses: zebradil/znix/.github/workflows/nix-ci.yaml@main
    with:
      discovery-types: checks
      push-to-cache: true
    secrets:
      cache-signing-key: ${{ secrets.CACHE_PRIVATE_KEY }}
      cache-s3-url: ${{ secrets.CACHE_URL }}
      aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
      aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

## Rotating the CI age key

```bash
age-keygen -o /tmp/github-ci.txt          # new keypair
age-keygen -y /tmp/github-ci.txt          # public key -> &github-ci in .sops.yaml
sops updatekeys secrets/cache.yaml        # re-encrypt to the new recipient
```

Store the new private key (`AGE-SECRET-KEY-…`) as the `SOPS_AGE_KEY` repo secret.
