#!/usr/bin/env bash

# Turn the workaround registry into a probe matrix: one entry per
# (workaround, system) pair, on the runner that can build that system.
#
# Usage:
#   RUNNER_MAPPING="x86_64-linux:ubuntu-latest ..." workaround-matrix.sh
#   workaround-matrix.sh --self-test    run the pure-helper assert-based check
#
# Writes `matrix` and `has_targets` to $GITHUB_OUTPUT (stdout when unset).

set -euo pipefail

# --- pure helpers (exercised by --self-test, no nix needed) -------------------

# A system with no runner is dropped rather than failing the run: the probe is
# advisory, and a missing runner says nothing about whether upstream is fixed.
function build_matrix() {
	jq -c --argjson runners "${2:?runners is required}" '
	  [ to_entries[]
	    | .key as $name
	    | .value.systems[]
	    | select($runners[.] != null)
	    | { name: $name, system: ., runner: $runners[.] }
	  ] | { include: . }
	' <<<"${1:?registry is required}"
}

# Dropping is quiet but not free: workaround-propose.sh reads a missing verdict
# as "still broken", so an unmapped system makes its workaround permanently
# unremovable. Surface every pair rather than letting the matrix shrink silently.
function unmapped_pairs() {
	jq -r --argjson runners "${2:?runners is required}" '
	  to_entries[]
	  | .key as $name
	  | .value.systems[]
	  | select($runners[.] == null)
	  | "\($name) on \(.)"
	' <<<"${1:?registry is required}"
}

# --- self-test ---------------------------------------------------------------

function self_test() {
	local registry runners matrix expected
	registry='{
	  "mapped":  {"systems": ["s1", "s2"]},
	  "partial": {"systems": ["s1", "s3"]}
	}'
	runners='{"s1": "r1", "s2": "r2"}'

	matrix=$(build_matrix "$registry" "$runners")
	expected='{"include":[{"name":"mapped","system":"s1","runner":"r1"},{"name":"mapped","system":"s2","runner":"r2"},{"name":"partial","system":"s1","runner":"r1"}]}'
	[[ "$matrix" == "$expected" ]] || {
		echo "self-test FAILED (unexpected matrix: $matrix)" >&2
		return 1
	}

	[[ "$(unmapped_pairs "$registry" "$runners")" == "partial on s3" ]] || {
		echo "self-test FAILED (a system with no runner must be reported)" >&2
		return 1
	}

	[[ "$(build_matrix '{}' "$runners")" == '{"include":[]}' ]] || {
		echo "self-test FAILED (an empty registry must yield an empty matrix)" >&2
		return 1
	}

	echo "self-test OK"
}

if [[ "${1:-}" == "--self-test" ]]; then
	self_test
	exit $?
fi

# --- main --------------------------------------------------------------------

registry=$(nix eval --json .#workaroundRegistry)

mapping='{}'
for pair in ${RUNNER_MAPPING:?RUNNER_MAPPING is required}; do
	mapping=$(jq -c --arg s "${pair%%:*}" --arg r "${pair#*:}" '. + {($s): $r}' <<<"$mapping")
done

while IFS= read -r pair; do
	[[ -n "$pair" ]] || continue
	echo "::warning::workaround-probe: no runner for ${pair}, so that workaround can never be proposed for removal"
done <<<"$(unmapped_pairs "$registry" "$mapping")"

matrix=$(build_matrix "$registry" "$mapping")

count=$(jq '.include | length' <<<"$matrix")
for line in "matrix=$matrix" "has_targets=$([[ $count -gt 0 ]] && echo true || echo false)"; do
	echo "$line" >>"${GITHUB_OUTPUT:-/dev/stdout}"
done

echo "::notice::workaround-probe: $count probe target(s)"
