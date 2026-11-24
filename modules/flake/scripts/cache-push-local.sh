#!/usr/bin/env bash
set -euo pipefail

# Local entrypoint for `nix run .#cache-push -- <attr>...`.
#
# Decrypts the binary-cache secrets from secrets/cache.yaml (using your personal
# sops/age key) and hands off to kasha-cache-push, the resolve -> sign -> push
# core that CI also uses. Run from a checkout of this flake.
#
# Usage:
#   nix run .#cache-push                  # publish every checks.<system>.* output
#   nix run .#cache-push -- ATTR [ATTR…]  # publish specific flake attrs
#   nix run .#cache-push -- --via-box …   # push to the LAN kasha box instead of R2;
#                                         # the box uploads to R2 in the background

flake="$(git rev-parse --show-toplevel 2>/dev/null || true)"
flake="${flake:-$PWD}"

sops_file="$flake/secrets/cache.yaml"
if [[ ! -f "$sops_file" ]]; then
  echo "error: $sops_file not found — run this from a checkout of the flake." >&2
  exit 1
fi

via_box=""
args=()
for a in "$@"; do
  if [[ "$a" == --via-box ]]; then via_box=1; else args+=("$a"); fi
done

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

key_file="$workdir/signing.key"
(
  umask 077
  sops decrypt --extract '["SIGNING_KEY"]' "$sops_file" >"$key_file"
)

export CACHE_SIGNING_KEY_FILE="$key_file"

if [[ -n "$via_box" ]]; then
  # The box (daddy) serves this host name; see modules/hosts/daddy/configuration.nix.
  KASHA_BOX_URL="https://kasha.lan.zebradil.dev"
  KASHA_TOKEN="$(sops decrypt --extract '["kasha-token"]' "$flake/secrets/hosts/daddy.yaml")"
  export KASHA_BOX_URL KASHA_TOKEN
else
  CACHE_S3_URL="$(sops decrypt --extract '["CACHE_S3_URL"]' "$sops_file")"
  AWS_ACCESS_KEY_ID="$(sops decrypt --extract '["AWS_ACCESS_KEY_ID"]' "$sops_file")"
  AWS_SECRET_ACCESS_KEY="$(sops decrypt --extract '["AWS_SECRET_ACCESS_KEY"]' "$sops_file")"
  export CACHE_S3_URL AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
fi

exec kasha-cache-push ${args[@]+"${args[@]}"}
