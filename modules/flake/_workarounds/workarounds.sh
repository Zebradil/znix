# CI steps of the workarounds framework; see docs/workarounds.md, "Probing".
# Packaged by writeShellApplication, which adds the shebang and `set -euo pipefail`.
#
#   workarounds matrix                          RUNNER_MAPPING="<system>:<runner> ..."
#   workarounds probe <name> <system> <dir>     writes <dir>/<name>__<system>.json
#   workarounds propose <dir>                   GH_TOKEN, HAS_APP_TOKEN
#   workarounds self-test

usage() {
	cat >&2 <<-TXT
		usage: workarounds matrix
		       workarounds probe <name> <system> <verdict-dir>
		       workarounds propose <verdict-dir>
		       workarounds self-test
	TXT
	exit 64
}

# --- pure helpers (exercised by self-test; no nix, git, or gh) ---------------

# A system with no runner is dropped rather than failing the run, but reported:
# its verdict will be missing, and a missing verdict blocks removal forever.
build_matrix() {
	jq -c --argjson runners "$2" '
	  [ to_entries[] | .key as $name | .value.systems[]
	    | select($runners[.] != null)
	    | { name: $name, system: ., runner: $runners[.] } ]
	  | { include: . }' <<<"$1"
}

unmapped_pairs() {
	jq -r --argjson runners "$2" '
	  to_entries[] | .key as $name | .value.systems[]
	  | select($runners[.] == null) | "\($name) on \(.)"' <<<"$1"
}

# Removable only when every claimed system came back ok. A missing verdict means
# the probe never ran (no runner, cancelled job): unknown is not fixed.
is_fixed() {
	local name=$1 registry=$2 dir=$3 system verdict
	for system in $(jq -r --arg n "$name" '.[$n].systems[]' <<<"$registry"); do
		verdict="$dir/${name}__${system}.json"
		[[ -f $verdict ]] || return 1
		[[ $(jq -r .ok "$verdict") == true ]] || return 1
	done
}

runner_mapping_json() {
	local pair json='{}'
	for pair in $1; do
		json=$(jq -c --arg s "${pair%%:*}" --arg r "${pair#*:}" '. + {($s): $r}' <<<"$json")
	done
	echo "$json"
}

# --- commands ------------------------------------------------------------------

cmd_matrix() {
	local registry runners matrix count pair
	registry=$(nix eval --json .#workarounds.registry)
	runners=$(runner_mapping_json "${RUNNER_MAPPING:?RUNNER_MAPPING is required}")

	while IFS= read -r pair; do
		if [[ -n $pair ]]; then
			echo "::warning::workarounds: no runner for ${pair}, so it can never be proposed for removal"
		fi
	done <<<"$(unmapped_pairs "$registry" "$runners")"

	matrix=$(build_matrix "$registry" "$runners")
	count=$(jq '.include | length' <<<"$matrix")
	{
		echo "matrix=$matrix"
		echo "has_targets=$([[ $count -gt 0 ]] && echo true || echo false)"
	} >>"${GITHUB_OUTPUT:-/dev/stdout}"
	echo "::notice::workarounds: $count probe target(s)"
}

# A failed build is the expected outcome, so this exits 0 either way; only an
# unwritable verdict fails it.
cmd_probe() {
	local name=${1:?name} system=${2:?system} dir=${3:?dir} paths ok=false
	mkdir -p "$dir"
	if paths=$(nix build --no-link --print-out-paths ".#workarounds.probes.${system}.${name}"); then
		ok=true
		echo "::notice::workarounds: ${name} probe builds on ${system}, so the workaround may be removable"
	else
		paths=
		echo "::notice::workarounds: ${name} probe fails on ${system}, so the workaround is still needed"
	fi
	jq -n --arg n "$name" --arg s "$system" --argjson ok "$ok" --arg p "$paths" \
		'{name: $n, system: $s, ok: $ok, paths: ($p | split("\n") | map(select(. != "")))}' \
		>"$dir/${name}__${system}.json"
}

pr_body() {
	local name=$1 file=$2 reason=$3
	# A PR pushed with GITHUB_TOKEN raises no pull_request event, so the CI this
	# PR exists to run never starts, and an empty check list looks clean.
	if [[ ${HAS_APP_TOKEN:-} != true ]]; then
		cat <<-MD
			> [!WARNING]
			> Opened with \`GITHUB_TOKEN\`, so CI did **not** start. Close and reopen this
			> PR, or push an empty commit, before reading anything into the checks.

		MD
	fi
	cat <<-MD
		The probe for \`${name}\` builds against the candidate lock (\`nix flake update\`
		of the default branch) on every system the workaround claims, so upstream no
		longer needs it.

		**Workaround being removed** (\`${file}\`):
		> ${reason}

		This PR also carries the candidate lock. The probe only shows that upstream is
		fixed; CI on this PR shows every configuration still builds without the
		workaround. Read the checks before merging.
	MD
}

# flake-file regenerates flake.nix, which a removed pin's input must leave.
has_write_flake() {
	# shellcheck disable=SC2016 # ${s} is Nix, not shell
	[[ $(nix eval .#apps --apply 'a: builtins.any (s: a.${s} ? write-flake) (builtins.attrNames a)') == true ]]
}

# Returns 0 even on failure: one entry failing to reach GitHub (rate limit, org
# policy) must not strand the others. A branch pushed without its PR is retried
# on the next run.
propose_removal() {
	local name=$1 file=$2 reason=$3 base=$4 candidate=$5 pr=$6 branch="automation/drop-workaround-$1"

	git switch --quiet --force-create "$branch" "$base"
	cp "$candidate" flake.lock
	if ! git diff --quiet -- flake.lock; then
		git commit --quiet -m "chore: update flake.lock" -- flake.lock
	fi

	if ! {
		git rm --quiet -- "$file" &&
			{ ! has_write_flake || { nix run .#write-flake && git add flake.nix; }; } &&
			nix flake lock && git add flake.lock &&
			git commit --quiet -m "chore: drop the ${name} workaround" \
				-m "Its probe builds against the updated inputs, so upstream no longer needs it."
	}; then
		echo "::warning::workarounds: could not remove '${name}' cleanly, skipping"
		git reset --quiet --hard
		git switch --quiet --force "$base"
		return 0
	fi

	# Rebuilt on the current base every run, even with a PR open: the removal is
	# only meaningful against today's candidate lock.
	if ! git push --quiet --force origin "$branch" ||
		! { [[ -n $pr ]] || gh pr create --base "$base" --head "$branch" \
			--title "chore: drop the ${name} workaround" --body "$(pr_body "$name" "$file" "$reason")"; }; then
		echo "::warning::workarounds: could not open the removal PR for '${name}', skipping"
	fi
	git switch --quiet --force "$base"
}

cmd_propose() {
	local dir=${1:?verdict dir} registry base candidate name pr
	registry=$(nix eval --json .#workarounds.registry)
	base=$(git rev-parse --abbrev-ref HEAD)

	# The working tree holds the candidate lock; every branch starts from the
	# base's committed lock and takes the candidate on top.
	candidate=$(mktemp)
	cp flake.lock "$candidate"
	git checkout --quiet -- flake.lock

	git config user.name "github-actions[bot]"
	git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

	for name in $(jq -r 'keys[]' <<<"$registry"); do
		pr=$(gh pr list --head "automation/drop-workaround-${name}" --state open --json number --jq '.[0].number // empty')
		if is_fixed "$name" "$registry" "$dir"; then
			propose_removal "$name" \
				"$(jq -r --arg n "$name" '.[$n].file' <<<"$registry")" \
				"$(jq -r --arg n "$name" '.[$n].reason' <<<"$registry")" \
				"$base" "$candidate" "$pr"
			echo "::notice::workarounds: removal PR for '${name}' ${pr:+#$pr }is up to date"
		elif [[ -n $pr ]]; then
			gh pr close "$pr" --delete-branch --comment \
				"The probe for \`${name}\` fails again, so upstream still needs this workaround. A later probe reopens it if that changes."
			echo "::notice::workarounds: closed stale PR #${pr} for '${name}'"
		fi
	done
}

# --- self-test -----------------------------------------------------------------

cmd_self_test() {
	local registry runners dir
	fail() {
		echo "self-test FAILED: $1" >&2
		exit 1
	}

	registry='{"mapped": {"systems": ["s1", "s2"]}, "partial": {"systems": ["s1", "s3"]}}'
	runners=$(runner_mapping_json "s1:r1 s2:r2")
	[[ $runners == '{"s1":"r1","s2":"r2"}' ]] || fail "runner mapping: $runners"
	[[ $(build_matrix "$registry" "$runners") == '{"include":[{"name":"mapped","system":"s1","runner":"r1"},{"name":"mapped","system":"s2","runner":"r2"},{"name":"partial","system":"s1","runner":"r1"}]}' ]] ||
		fail "matrix"
	[[ $(unmapped_pairs "$registry" "$runners") == "partial on s3" ]] || fail "a system with no runner must be reported"
	[[ $(build_matrix '{}' "$runners") == '{"include":[]}' ]] || fail "an empty registry must yield an empty matrix"

	registry='{"all-ok": {"systems": ["s1", "s2"]}, "partial": {"systems": ["s1", "s2"]},
	           "missing": {"systems": ["s1", "s2"]}, "failed": {"systems": ["s1"]}}'
	dir=$(mktemp -d)
	echo '{"ok": true}' >"$dir/all-ok__s1.json"
	echo '{"ok": true}' >"$dir/all-ok__s2.json"
	echo '{"ok": true}' >"$dir/partial__s1.json"
	echo '{"ok": false}' >"$dir/partial__s2.json"
	echo '{"ok": true}' >"$dir/missing__s1.json"
	echo '{"ok": false}' >"$dir/failed__s1.json"
	is_fixed all-ok "$registry" "$dir" || fail "all systems ok must be removable"
	! is_fixed partial "$registry" "$dir" || fail "one system still broken must block removal"
	! is_fixed missing "$registry" "$dir" || fail "a missing verdict must block removal"
	! is_fixed failed "$registry" "$dir" || fail "a failed probe must block removal"
	rm -rf "$dir"

	echo "self-test OK"
}

case "${1:-}" in
matrix) cmd_matrix ;;
probe) cmd_probe "${@:2}" ;;
propose) cmd_propose "${@:2}" ;;
self-test) cmd_self_test ;;
*) usage ;;
esac
