#!/usr/bin/env bash

# Filters a build matrix down to targets that still have something to build.
#
# For each target it computes the build-set — the genuinely-uncached
# derivations (build-set.sh) — and drops the target when that set is empty,
# i.e. every derivation it needs is already substitutable from a configured
# cache. Such targets would spin a runner only to build nothing, so they are
# skipped. Everything else is kept.
#
# Under the build-uncached-only CI (the top-level is never realized/pushed) the
# target's own top-level narinfo is never in the cache, so probing for it would
# rebuild every target on every push. Probing the build-set restores the
# skip-unchanged saving without depending on a top-level NAR.
#
# On any uncertainty (eval failure, no cache URL) the target is kept — building
# is the safe default that preserves the "main is always green and cached"
# invariant.
#
# Inputs (env):
#   MATRIX    - JSON object '{"include":[{"attr":...,"system":...,"runner":...}]}'.
#   CACHE_URL - HTTPS base URL of the binary cache (probing needs it configured
#               as a substituter; empty disables probing and builds all).
#
# Outputs ($GITHUB_OUTPUT):
#   matrix      - filtered '{"include":[...]}' object.
#   has_targets - 'true' if at least one target still needs building.

set -euo pipefail

: "${MATRIX:?MATRIX is required}"
cache_url="${CACHE_URL:-}"

script_dir=$(cd "$(dirname "$0")" && pwd)

include=$(jq -c '.include // []' <<<"$MATRIX")
n=$(jq 'length' <<<"$include")

filtered='[]'

for ((i = 0; i < n; i++)); do
	entry=$(jq -c ".[$i]" <<<"$include")
	attr=$(jq -r '.attr' <<<"$entry")

	keep=true
	if [[ -z "$cache_url" ]]; then
		echo "probe-cache: no cache URL configured; building ${attr}"
	elif ! drvs=$("$script_dir/build-set.sh" "$attr" 2>/dev/null); then
		echo "::warning::probe-cache: build-set eval failed for ${attr}; building to be safe"
	elif [[ -z "$drvs" ]]; then
		echo "::notice::probe-cache: ${attr} has an empty build-set (all cached); skipping build"
		keep=false
	else
		count=$(grep -c . <<<"$drvs")
		echo "probe-cache: ${attr} has ${count} derivation(s) to build"
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
