#!/usr/bin/env bash
set -euo pipefail

# Entrypoint for `nix run .#cache-onboard -- [OWNER/]REPO`.
#
# Copies the binary-cache credentials from secrets/cache.yaml into a GitHub
# repository's Actions secrets (plus the CACHE_S3_URL variable), so its CI can
# push to the cache. Run from a checkout of this flake. A bare REPO resolves
# against the authenticated gh user.

if [[ $# -ne 1 ]]; then
  echo "usage: cache-onboard [OWNER/]REPO" >&2
  exit 2
fi

repo="$1"
[[ "$repo" == */* ]] || repo="$(gh api user --jq .login)/$repo"

flake="$(git rev-parse --show-toplevel 2>/dev/null || true)"
sops_file="${flake:-$PWD}/secrets/cache.yaml"
if [[ ! -f "$sops_file" ]]; then
  echo "error: $sops_file not found — run this from a checkout of the flake." >&2
  exit 1
fi

get() { sops decrypt --extract "[\"$1\"]" "$sops_file"; }

# Decrypt everything up front: a failed decrypt piped straight into
# `gh secret set` would still store an empty secret.
signing_key="$(get SIGNING_KEY)"
aws_access_key_id="$(get AWS_ACCESS_KEY_ID)"
aws_secret_access_key="$(get AWS_SECRET_ACCESS_KEY)"
s3_url="$(get CACHE_S3_URL)"

# printf is a builtin, so the values never appear in a process argv.
printf %s "$signing_key" | gh secret set CACHE_SIGNING_KEY --repo "$repo"
printf %s "$aws_access_key_id" | gh secret set AWS_ACCESS_KEY_ID --repo "$repo"
printf %s "$aws_secret_access_key" | gh secret set AWS_SECRET_ACCESS_KEY --repo "$repo"
gh variable set CACHE_S3_URL --repo "$repo" --body "$s3_url"
