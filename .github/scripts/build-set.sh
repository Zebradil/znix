#!/usr/bin/env bash

# Print the derivations that WOULD be built for a flake attr, EXCLUDING the
# attr's own top-level derivation.
#
# This is the CI buildability gate set: the genuinely-uncached derivations whose
# build proves they still compile on the consumer's system. Realizing the
# top-level itself is deliberately skipped — its build step only links an
# already-substitutable closure together, so building it would fetch the entire
# runtime closure just to symlink it. The box realizes the top-level later, from
# its pushed .drv (it has the disk); CI only needs to prove the leaves build.
#
# Usage:
#   build-set.sh <flake-attr>     print one .drv path per line (may be empty)
#   build-set.sh --self-test      run the parser's assert-based self-check
#
# Exits non-zero only on eval failure. An empty set (exit 0, no output) means
# nothing uncached is left to build — the caller may skip the whole target.

set -euo pipefail

# Extract the `.drv` paths under `nix-store --realise --dry-run`'s
# "these N derivations will be built:" block, dropping the top-level drv passed
# as $1. Reads the (stdout+stderr-merged) plan on stdin. Split out from the nix
# call so it can be exercised by --self-test without a store.
parse_to_build() {
	local top_drv="$1"
	sed -n '/will be built/,/will be fetched/p' \
		| grep -oE '/nix/store/[^ ]+\.drv' \
		| grep -vxF "$top_drv" || true
}

self_test() {
	local top='/nix/store/tttttttttttttttttttttttttttttttt-darwin-system.drv'
	local plan
	# A representative dry-run plan: a built block (incl. the top-level, which
	# must be dropped) followed by a fetched block (which must be ignored).
	plan=$(
		cat <<-EOF
			these 3 derivations will be built:
			  /nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-foo.drv
			  ${top}
			  /nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-bar.drv
			these 808 paths will be fetched (821.4 MiB download, 4.3 GiB unpacked):
			  /nix/store/cccccccccccccccccccccccccccccccc-should-not-appear.drv
			  /nix/store/dddddddddddddddddddddddddddddddd-pkg
		EOF
	)
	local got
	got=$(printf '%s\n' "$plan" | parse_to_build "$top")
	local want='/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-foo.drv
/nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-bar.drv'
	if [[ "$got" != "$want" ]]; then
		echo "self-test FAILED" >&2
		echo "want:" >&2; printf '%s\n' "$want" >&2
		echo "got:" >&2; printf '%s\n' "$got" >&2
		return 1
	fi
	# An all-cached plan (only a fetched block) yields an empty set.
	got=$(printf 'these 5 paths will be fetched (1 MiB):\n  /nix/store/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee-pkg\n' \
		| parse_to_build "$top")
	[[ -z "$got" ]] || { echo "self-test FAILED: expected empty set" >&2; return 1; }
	echo "self-test OK"
}

if [[ "${1:-}" == "--self-test" ]]; then
	self_test
	exit $?
fi

attr="${1:?usage: build-set.sh <flake-attr>|--self-test}"

top_drv="$(nix path-info --derivation ".#${attr}")"

# --dry-run plans the build without doing it: it lists what it would build and
# what it would substitute. We keep only the "will be built" derivations.
nix-store --realise --dry-run "$top_drv" 2>&1 | parse_to_build "$top_drv"
