#!/usr/bin/env bash

# Filters a build matrix down to targets that are NOT yet in the binary cache.
#
# For each target in MATRIX, evaluates its output store path (pure eval, no build,
# works cross-system) and probes the cache for the corresponding `.narinfo`. Targets
# already present are dropped so they never spin a runner; everything else is kept.
#
# On any uncertainty (eval failure, no cache URL) the target is kept — building is the
# safe default that preserves the "main is always green and cached" invariant.
#
# Inputs (env):
#   MATRIX    - JSON object '{"include":[{"attr":...,"system":...,"runner":...}]}'.
#   CACHE_URL - HTTPS base URL of the binary cache to probe. Empty disables probing.
#
# Outputs ($GITHUB_OUTPUT):
#   matrix      - filtered '{"include":[...]}' object.
#   has_targets - 'true' if at least one target still needs building.

set -euo pipefail

: "${MATRIX:?MATRIX is required}"
cache_url="${CACHE_URL:-}"

include=$(jq -c '.include // []' <<<"$MATRIX")
n=$(jq 'length' <<<"$include")

filtered='[]'

for ((i = 0; i < n; i++)); do
	entry=$(jq -c ".[$i]" <<<"$include")
	attr=$(jq -r '.attr' <<<"$entry")

	keep=true
	if [[ -z "$cache_url" ]]; then
		echo "probe-cache: no cache URL configured; building ${attr}"
	elif ! out=$(nix eval --raw ".#${attr}.outPath" 2>/dev/null); then
		echo "::warning::probe-cache: failed to eval ${attr}.outPath; building to be safe"
	else
		hash=$(basename "$out")
		hash="${hash%%-*}"
		if curl -fsI -o /dev/null --max-time 20 "${cache_url%/}/${hash}.narinfo"; then
			echo "::notice::probe-cache: ${attr} already cached (${hash}); skipping build"
			keep=false
		else
			echo "probe-cache: ${attr} not in cache (${hash}); will build"
		fi
	fi

	if [[ "$keep" == true ]]; then
		filtered=$(jq -c --argjson e "$entry" '. + [$e]' <<<"$filtered")
	fi
done

count=$(jq 'length' <<<"$filtered")
matrix=$(jq -c '{include: .}' <<<"$filtered")
has_targets="false"
[[ "$count" -gt 0 ]] && has_targets="true"

echo "probe-cache: ${count}/${n} target(s) need building"
{
	echo "matrix=${matrix}"
	echo "has_targets=${has_targets}"
} >>"$GITHUB_OUTPUT"
