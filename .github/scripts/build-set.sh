#!/usr/bin/env bash

# Print the derivations CI should actually build for a flake attr: the
# genuinely-uncached *leaf* derivations, EXCLUDING both the top-level and the
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
# So we keep only candidates whose own build does NOT pull in a large chunk of
# the closure: a real leaf's build fetches a handful of (mostly cached) inputs;
# an assembly drv's build fetches basically the whole closure. We measure that
# directly — each candidate gets its own --dry-run and we count what IT would
# fetch. (The narinfo probed by the top-level dry-run is disk-cached, so the
# per-candidate dry-runs are cheap.) The buildability gate is preserved for the
# leaves (the things that can fail to compile); the tower is assembled later by
# the consumer, which already has the disk.
#
# Usage:
#   build-set.sh <flake-attr>     print one .drv path per line (may be empty)
#   build-set.sh --self-test      run the parser's assert-based self-check
#
# Env:
#   BUILD_SET_MAX_FETCH   max paths a candidate's own build may fetch before it
#                         is treated as an assembly drv and skipped (default
#                         50). ponytail: a fixed cutoff, not a fraction of the
#                         closure — bump it if a legitimately heavy leaf package
#                         (large uncached build-input set) gets skipped.
#
# Exits non-zero only on eval failure. An empty set (exit 0, no output) means
# nothing uncached-and-cheap is left to build — the caller may skip the target.

set -euo pipefail

: "${BUILD_SET_MAX_FETCH:=50}"

# --- pure parsers/helpers (exercised by --self-test, no store needed) --------

# Drv paths under the "these N derivations will be built:" block, dropping the
# top-level drv ($1). Reads the merged dry-run plan on stdin.
parse_built() {
	local top_drv="$1"
	sed -n '/will be built/,/will be fetched/p' \
		| grep -oE '/nix/store/[^ ]+\.drv' \
		| grep -vxF "$top_drv" || true
}

# Store paths under the "these N paths will be fetched (...)" block — the
# outputs that would be downloaded to the runner. Reads the plan on stdin.
# The header line carries no /nix/store token, so it is naturally excluded.
parse_fetched() {
	sed -n '/will be fetched/,$p' \
		| grep -oE '/nix/store/[^ ]+' || true
}

# Number of store paths in the "will be fetched" block of a dry-run plan on
# stdin — i.e. how much a build would download. Zero when nothing is fetched.
count_fetched() {
	parse_fetched | grep -c . || true
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

	got=$(parse_fetched <<<"$plan")
	want='/nix/store/cccccccccccccccccccccccccccccccc-pkg-a
/nix/store/dddddddddddddddddddddddddddddddd-pkg-b'
	[[ "$got" == "$want" ]] || { echo "self-test FAILED (parse_fetched)" >&2; printf 'got:\n%s\n' "$got" >&2; return 1; }

	# An all-cached plan (only a fetched block) yields no candidates.
	got=$(parse_built "$top" <<<'these 5 paths will be fetched (1 MiB):
  /nix/store/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee-pkg')
	[[ -z "$got" ]] || { echo "self-test FAILED (expected no candidates)" >&2; return 1; }

	# count_fetched: a leaf plan (no fetched block) is 0; an assembly plan
	# reports its full fetched block.
	[[ "$(count_fetched <<<'this derivation will be built:
  /nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-leaf.drv')" == 0 ]] \
		|| { echo "self-test FAILED (leaf count != 0)" >&2; return 1; }
	[[ "$(count_fetched <<<"$plan")" == 2 ]] \
		|| { echo "self-test FAILED (assembly count != 2)" >&2; return 1; }

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
# what it would substitute. Everything else derives from this single plan.
plan="$(nix-store --realise --dry-run "$top_drv" 2>&1)"

candidates="$(parse_built "$top_drv" <<<"$plan")"
[[ -n "$candidates" ]] || exit 0

# Keep a candidate only when its own build would fetch few paths. Its dry-run
# reuses the narinfo the top-level dry-run already cached, so this is a cheap
# store/network query, not a rebuild. Assembly drvs reference ~everything and
# blow past the cutoff; real leaves fetch a handful.
while IFS= read -r drv; do
	[[ -n "$drv" ]] || continue
	n="$(nix-store --realise --dry-run "$drv" 2>&1 | count_fetched)"
	if ((n <= BUILD_SET_MAX_FETCH)); then
		printf '%s\n' "$drv"
	else
		echo "build-set: skipping assembly drv (${n} paths to fetch > ${BUILD_SET_MAX_FETCH}): ${drv}" >&2
	fi
done <<<"$candidates"
