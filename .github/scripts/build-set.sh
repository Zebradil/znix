#!/usr/bin/env bash

# Print the derivations CI should actually build for a flake attr: the
# genuinely-uncached *real* derivations, EXCLUDING both the top-level and the
# whole assembly tower beneath it.
#
# Why this is not just "uncached minus the top-level":
# A NixOS/darwin/home-manager system is a tower of pure-aggregation
# derivations — system-path, etc, system-units, activate, home-manager-files,
# home-manager-generation, the per-unit scripts — sitting between the top-level
# and the real packages. None of them compile anything; they symlink/concat the
# runtime closure. So building one can never catch a package that fails to
# build, yet it references the *whole* closure and drags every path onto the
# runner (GBs) — the disk-exhaustion these runners die on.
#
# How we tell an aggregator from a real build: by how much of the top-level's
# derivation closure it references. An aggregator links ~everything, so its own
# .drv input closure is essentially the top-level's (~100%); a real package —
# even a heavy one — references only its own build closure (a small fraction).
# We compare each candidate's .drv closure size to the top-level's and skip the
# ones at or above BUILD_SET_MAX_CLOSURE_PCT.
#
# This metric is store-state INDEPENDENT: the .drv graph is fully materialized
# once `nix path-info --derivation` instantiates the top-level, so the counts
# never depend on what the runner happens to have substituted. (An earlier
# version counted what each candidate's *build* would fetch — that number is the
# build-input closure on a cold runner, which is large for any heavy package, so
# real packages like keepassxc/neovim got misclassified as aggregators and were
# never built or pushed.)
#
# Usage:
#   build-set.sh <flake-attr>     print one .drv path per line (may be empty)
#   build-set.sh --self-test      run the pure-helper assert-based self-check
#
# Env:
#   BUILD_SET_MAX_CLOSURE_PCT   a candidate whose .drv input closure is >= this
#                               percentage of the top-level's is treated as an
#                               aggregation drv and skipped (default 90).
#                               ponytail: real builds sit far below the tower
#                               (measured: packages <25%, a plugin-heavy neovim
#                               ~52%, the aggregators 98-101%), so the exact
#                               cutoff is not delicate — lower it only if a new
#                               aggregator variant slips through.
#
# Exits non-zero only on eval failure. An empty set (exit 0, no output) means
# nothing uncached-and-real is left to build — the caller may skip the target.

set -euo pipefail

: "${BUILD_SET_MAX_CLOSURE_PCT:=90}"

# --- pure helpers (exercised by --self-test, no store needed) ----------------

# Drv paths under the "these N derivations will be built:" block, dropping the
# top-level drv ($1). Reads the merged dry-run plan on stdin.
parse_built() {
	local top_drv="$1"
	sed -n '/will be built/,/will be fetched/p' \
		| grep -oE '/nix/store/[^ ]+\.drv' \
		| grep -vxF "$top_drv" || true
}

# Is a candidate an aggregation drv? True when its .drv closure ($1) is at least
# $3 percent of the top-level's ($2). Guards a zero/empty top size (treat as
# not-aggregator so nothing is silently dropped on a bad measurement).
is_aggregator() {
	local size="$1" top="$2" pct="$3"
	((top > 0)) || return 1
	((size * 100 >= top * pct))
}

# --- store queries -----------------------------------------------------------

# Number of derivations in a drv's input closure. Warmth-independent: every
# input .drv is present once the top-level is instantiated.
drv_closure_size() {
	nix-store --query --requisites "$1" 2>/dev/null | grep -c '\.drv$' || true
}

# --- self-test ---------------------------------------------------------------

self_test() {
	local top='/nix/store/tttttttttttttttttttttttttttttttt-darwin-system.drv'
	local plan
	plan=$(
		cat <<-EOF
			these 3 derivations will be built:
			  /nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-foo.drv
			  ${top}
			  /nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-bar.drv
			these 808 paths will be fetched (821.4 MiB download, 4.3 GiB unpacked):
			  /nix/store/cccccccccccccccccccccccccccccccc-pkg-a
			  /nix/store/dddddddddddddddddddddddddddddddd-pkg-b
		EOF
	)

	local got want
	got=$(parse_built "$top" <<<"$plan")
	want='/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-foo.drv
/nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-bar.drv'
	[[ "$got" == "$want" ]] || { echo "self-test FAILED (parse_built)" >&2; printf 'got:\n%s\n' "$got" >&2; return 1; }

	# An all-cached plan (only a fetched block) yields no candidates.
	got=$(parse_built "$top" <<<'these 5 paths will be fetched (1 MiB):
  /nix/store/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee-pkg')
	[[ -z "$got" ]] || { echo "self-test FAILED (expected no candidates)" >&2; return 1; }

	# is_aggregator, using the measured shape (top=7372): the tower clusters at
	# ~100%, a plugin-heavy neovim at ~52%, ordinary packages under 25%.
	is_aggregator 7334 7372 90    || { echo "self-test FAILED (tower not flagged)" >&2; return 1; }
	! is_aggregator 3835 7372 90  || { echo "self-test FAILED (heavy build flagged)" >&2; return 1; }
	! is_aggregator 1237 7372 90  || { echo "self-test FAILED (package flagged)" >&2; return 1; }
	# A zero top size never drops a candidate.
	! is_aggregator 100 0 90      || { echo "self-test FAILED (zero-top guard)" >&2; return 1; }

	echo "self-test OK"
}

if [[ "${1:-}" == "--self-test" ]]; then
	self_test
	exit $?
fi

# --- main --------------------------------------------------------------------

attr="${1:?usage: build-set.sh <flake-attr>|--self-test}"

top_drv="$(nix path-info --derivation ".#${attr}")"

# One dry-run plans the whole build without doing it: what it would build and
# what it would substitute. This tells us which candidates are uncached (the
# "will be built" block) — the only ones worth building and pushing.
plan="$(nix-store --realise --dry-run "$top_drv" 2>&1)"

candidates="$(parse_built "$top_drv" <<<"$plan")"
[[ -n "$candidates" ]] || exit 0

# Size the top-level's derivation closure once; each candidate is judged as a
# fraction of it.
top_size="$(drv_closure_size "$top_drv")"
((top_size > 0)) || { echo "build-set: empty top-level drv closure for ${attr}" >&2; exit 1; }

while IFS= read -r drv; do
	[[ -n "$drv" ]] || continue
	size="$(drv_closure_size "$drv")"
	if is_aggregator "$size" "$top_size" "$BUILD_SET_MAX_CLOSURE_PCT"; then
		echo "build-set: skipping aggregation drv (${size}/${top_size} drvs >= ${BUILD_SET_MAX_CLOSURE_PCT}%): ${drv}" >&2
	else
		printf '%s\n' "$drv"
	fi
done <<<"$candidates"
