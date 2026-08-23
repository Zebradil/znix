#!/usr/bin/env bash
set -euo pipefail

# Build the kasha emitter from the target repo's flake, publish it to the
# binary cache, and export the manifest provenance fields to $GITHUB_OUTPUT.
#
# Shared by the build-and-publish composite action and nix-update-pr.yaml so
# the gen-id construction and the emitter push live in one place.
#
#   $1  optional attr; appended to the gen id as a retention-group suffix.
#
# Reads CACHE_S3_URL / CACHE_SIGNING_KEY_FILE / AWS_* (forwarded to
# kasha-cache-push, which owns the sign + push + URL-shape checks) and
# GITHUB_REF_NAME. Writes bin=, branch= and gen= to $GITHUB_OUTPUT.

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
attr="${1:-}"

san() { printf '%s' "$1" | tr -c 'A-Za-z0-9_.-' '-'; }

# `^out` pins the single output: --print-out-paths emits one line per output,
# and a multi-line $out would silently produce a broken bin path below.
out="$(nix build --no-link --print-out-paths '.#kasha^out')"

# Publish the emitter through the shared push core (KASHA_* cleared: this is a
# plain closure push, not a generation). Sibling and later jobs then substitute
# it instead of rebuilding it. The remote GC sweep drops it again (no manifest
# references it), which only costs one rebuild per sweep.
printf '%s\n' "$out" > "${RUNNER_TEMP:-/tmp}/kasha-emitter-path.txt"
core="$(bash "$here/resolve-cache-push.sh")"
KASHA_FLAKE='' KASHA_BIN='' \
  "$core" --paths-file "${RUNNER_TEMP:-/tmp}/kasha-emitter-path.txt"

branch="$(san "$GITHUB_REF_NAME")"
gen="${branch}-$(git rev-parse --short HEAD)"
if [[ -n "$attr" ]]; then
  gen="${gen}-$(san "$attr")"
fi
{
  echo "bin=$out/bin/kasha"
  echo "branch=$branch"
  echo "gen=$gen"
} >> "$GITHUB_OUTPUT"
