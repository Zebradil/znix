#!/usr/bin/env bash

# Act on probe results: a workaround whose vanilla package now builds on every
# system it claims gets a removal PR; one that regressed gets its stale removal
# PR closed.
#
# The probe only proves the *package* builds. The PR exists so the full CI
# matrix can prove the *hosts* still build without the workaround — which is why
# nothing here merges anything.
#
# Usage:
#   RESULTS_DIR=<dir of <name>__<system>.json> GH_TOKEN=... workaround-propose.sh
#   workaround-propose.sh --self-test    run the pure-helper assert-based check

set -euo pipefail

# --- pure helper (exercised by --self-test, no git/gh/nix needed) -------------

# A workaround is removable only when every system it claims came back ok. A
# missing verdict means the probe never ran (no runner for that system, or a
# cancelled job) — unknown is not fixed.
function is_fixed() {
	local name="${1:?name is required}" registry="${2:?registry is required}" system result

	for system in $(jq -r --arg n "$name" '.[$n].systems[]' <<<"$registry"); do
		result="$RESULTS_DIR/${name}__${system}.json"
		[[ -f "$result" ]] || return 1
		[[ $(jq -r '.ok' "$result") == "true" ]] || return 1
	done
}

# --- self-test ---------------------------------------------------------------

function self_test() {
	local registry
	registry='{
	  "all-ok":  {"systems": ["s1", "s2"]},
	  "partial": {"systems": ["s1", "s2"]},
	  "missing": {"systems": ["s1", "s2"]},
	  "failed":  {"systems": ["s1"]}
	}'

	RESULTS_DIR=$(mktemp -d)
	trap 'rm -rf "$RESULTS_DIR"' RETURN

	echo '{"ok": true}' >"$RESULTS_DIR/all-ok__s1.json"
	echo '{"ok": true}' >"$RESULTS_DIR/all-ok__s2.json"
	echo '{"ok": true}' >"$RESULTS_DIR/partial__s1.json"
	echo '{"ok": false}' >"$RESULTS_DIR/partial__s2.json"
	echo '{"ok": true}' >"$RESULTS_DIR/missing__s1.json"
	echo '{"ok": false}' >"$RESULTS_DIR/failed__s1.json"

	is_fixed all-ok "$registry" || {
		echo "self-test FAILED (all systems ok should be removable)" >&2
		return 1
	}
	! is_fixed partial "$registry" || {
		echo "self-test FAILED (one system still broken must block removal)" >&2
		return 1
	}
	! is_fixed missing "$registry" || {
		echo "self-test FAILED (missing verdict must block removal)" >&2
		return 1
	}
	! is_fixed failed "$registry" || {
		echo "self-test FAILED (failed probe must block removal)" >&2
		return 1
	}

	echo "self-test OK"
}

if [[ "${1:-}" == "--self-test" ]]; then
	self_test
	exit $?
fi

# --- main --------------------------------------------------------------------

: "${RESULTS_DIR:?RESULTS_DIR is required}"

# Removing a pin also removes its flake input, so the generated flake.nix and
# the lock must be regenerated. Both are no-ops for an override-only removal, so
# one code path covers every workaround kind.
function remove_workaround() {
	local file="${1:?file is required}"

	git rm --quiet "$file"
	nix run .#write-flake
	git add flake.nix
	nix flake lock
	git add flake.lock
}

function pr_body() {
	local name="${1:?}" file="${2:?}" reason="${3:?}"

	# A PR pushed with GITHUB_TOKEN raises no pull_request event, so the CI this
	# PR exists to run never starts — and an empty check list looks like a clean
	# one. Say so where the reviewer reads, not just in the run log.
	if [[ "${HAS_APP_TOKEN:-}" != "true" ]]; then
		cat <<-EOF
			> [!WARNING]
			> Opened with \`GITHUB_TOKEN\`, so CI did **not** trigger. Close and reopen this
			> PR, or push an empty commit, before reading anything into the checks.
			> Configuring the \`CI_APP_ID\` / \`CI_APP_PRIVATE_KEY\` secrets avoids this.

		EOF
	fi

	cat <<-EOF
		The weekly probe built \`${name}\` from vanilla nixpkgs on every system the
		workaround claimed, and it succeeded — upstream no longer needs the help.

		**Workaround being removed** (\`${file}\`):
		> ${reason}

		The probe only proves the package builds. CI on this PR proves the hosts do,
		so read the checks before merging.
	EOF
}

function propose_removal() {
	local name="${1:?}" branch="${2:?}" file="${3:?}" reason="${4:?}" base="${5:?}" pr="${6:-}"

	git switch --quiet --force-create "$branch" "$base"

	if ! remove_workaround "$file"; then
		echo "::warning::workaround-probe: could not regenerate the flake without '$name', skipping"
		git switch --quiet --force "$base"
		git reset --quiet --hard
		return 0
	fi

	git commit --quiet -m "chore: drop the ${name} workaround" \
		-m "Upstream nixpkgs builds ${name} unaided, so the workaround is dead weight."

	# One workaround failing to reach GitHub (org PR policy, rate limit) must not
	# strand the others, so this returns 0. A branch pushed without its PR is
	# retried next week: the open-PR lookup finds nothing and force-pushes again.
	#
	# The branch is rebuilt on the current base every week even when its PR is
	# already open: the removal is only meaningful against today's nixpkgs, and a
	# PR left sitting on a stale base tests a lock nobody will merge.
	if ! {
		git push --quiet --force origin "$branch" &&
			{
				[[ -n "$pr" ]] ||
					gh pr create \
						--title "chore: drop the ${name} workaround" \
						--head "$branch" \
						--body "$(pr_body "$name" "$file" "$reason")"
			}
	}; then
		echo "::warning::workaround-probe: could not open the removal PR for '$name', skipping"
		git switch --quiet --force "$base"
		return 0
	fi

	git switch --quiet --force "$base"
	return 0
}

registry=$(nix eval --json .#workaroundRegistry)
base=$(git rev-parse --abbrev-ref HEAD)

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

for name in $(jq -r 'keys[]' <<<"$registry"); do
	branch="automation/drop-workaround-${name}"
	pr=$(gh pr list --head "$branch" --state open --json number --jq '.[0].number // empty')

	if is_fixed "$name" "$registry"; then
		propose_removal "$name" "$branch" \
			"$(jq -r --arg n "$name" '.[$n].file' <<<"$registry")" \
			"$(jq -r --arg n "$name" '.[$n].reason' <<<"$registry")" \
			"$base" "$pr"
		if [[ -n "$pr" ]]; then
			echo "::notice::workaround-probe: rebased the removal PR #${pr} for '$name' onto ${base}"
		else
			echo "::notice::workaround-probe: opened a removal PR for '$name'"
		fi
	elif [[ -n "$pr" ]]; then
		gh pr close "$pr" --delete-branch --comment \
			"The probe for \`${name}\` failed again — upstream still needs this workaround. Closing; a later probe reopens it if that changes."
		echo "::notice::workaround-probe: closed stale PR #${pr} for '$name'"
	fi
done
