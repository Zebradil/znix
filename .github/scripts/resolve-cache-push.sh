#!/usr/bin/env bash
set -euo pipefail

# Print the path of the kasha-cache-push executable (resolve -> sign -> push).
#
# kasha owns that logic; this only locates it. Prefer the target repo's
# `.#kasha-cache-push`, which re-exports the kasha flake input and is therefore
# pinned by its flake.lock. Repos that reuse these workflows without wiring
# kasha have no such attr, so fall back to kasha's default branch — the same
# unpinned tracking they get from using these workflows at @main.

ref='github:Zebradil/kasha#kasha-cache-push'
if nix eval --raw '.#kasha-cache-push.outPath' >/dev/null 2>&1; then
  ref='.#kasha-cache-push'
fi

printf '%s/bin/kasha-cache-push\n' "$(nix build --no-link --print-out-paths "$ref")"
