#!/usr/bin/env bash

set -euo pipefail

declare -A runners
for pair in ${RUNNER_MAPPING:?RUNNER_MAPPING is required}; do
	runners["${pair%%:*}"]="${pair#*:}"
done

targets='[]'

# Add a target for a given type, name, system and optional attribute suffix
# Note: it updates the global targets variable.
# Usage: add_os_target <type> <name> <system> [<attribute-suffix>]
function add_os_target() {
	local type="${1:?type is required}"
	local name="${2:?name is required}"
	local sys="${3:?system is required}"
	local attr_suffix="${4:-}"

	local attr="${type}.${name}"
	if [[ -n "$attr_suffix" ]]; then
		attr="${attr}.${attr_suffix}"
	fi

	if ! [[ -v runners[$sys] ]]; then
		echo "::warning::nix-discover: system '$sys' not in the runner mapping, skipping"
		return 0
	fi

	targets=$(echo "$targets" | jq \
		--arg a "$attr" \
		--arg s "$sys" \
		--arg r "${runners[$sys]}" \
		'. + [{"attr":$a,"system":$s,"runner":$r}]')
}

# inventory v2 (Determinate Nix): top-level is {"version":2,"inventory":{...}}
# Older Nix emits the flat object directly; ".inventory // ." handles both.
flake_json=$(nix flake show . --json --all-systems | jq '.inventory // .')
if [[ "${NIX_DISCOVER_DEBUG:-}" =~ ^(1|true|yes)$ ]]; then
	echo "nix-discover: debug enabled, dumping full flake JSON"
	echo "$flake_json"
fi

for type in ${DISCOVERY_TYPES:?DISCOVERY_TYPES is required}; do
	# inventory v2 nests data under .output.children; fall back to direct key for old format.
	type_json=$(echo "$flake_json" | jq --arg t "$type" '.[$t].output.children // .[$t]')
	if [[ $type_json == "null" ]]; then
		echo "::warning::nix-discover: type '$type' not found in flake output, skipping"
		continue
	fi

	case "$type" in
	nixosConfigurations | darwinConfigurations)
		# inventory v2: each child carries forSystems directly — no nix eval needed.
		while read -r name sys; do
			add_os_target "$type" "$name" "$sys" "config.system.build.toplevel"
		done < <(echo "$type_json" | jq -r '
			to_entries[]
			| select(.value.filtered != true)
			| .key as $k
			| (.value.forSystems // [])[]
			| "\($k) \(.)"
		')
		;;
	*)
		# Per-system type (e.g. packages, devShells, checks, formatter).
		# inventory v2: system-level nodes are either a direct derivation (has "derivation" key)
		# or a container with a "children" map of named derivations.
		# Nodes with {"filtered":true} represent unavailable systems and must be skipped.
		while read -r sys; do
			sys_val=$(echo "$type_json" | jq --arg s "$sys" '.[$s]')

			if echo "$sys_val" | jq -e '.filtered == true' >/dev/null 2>&1; then
				continue
			fi

			if echo "$sys_val" | jq -e 'has("derivation") or has("type")' >/dev/null 2>&1; then
				# Direct derivation (e.g. formatter.x86_64-linux).
				add_os_target "$type" "$sys" "$sys"
			else
				# Named derivations (e.g. packages.x86_64-linux.default).
				# inventory v2 nests them under .children; old format uses keys directly.
				while read -r name; do
					add_os_target "$type" "$sys.$name" "$sys"
				done < <(echo "$sys_val" | jq -r '(.children // .) | keys[]')
			fi
		done < <(echo "$type_json" | jq -r 'keys[]')
		;;
	esac
done

# Apply optional attribute filter.
if [[ -n "${ATTR_FILTER:-}" ]]; then
	targets=$(echo "$targets" | jq --arg f "$ATTR_FILTER" '[.[] | select(.attr | test($f))]')
fi

echo "Found targets:"
echo "$targets"

# Summary log.
n=$(echo "$targets" | jq 'length')
echo "nix-discover: requested types: ${DISCOVERY_TYPES//$'\n'/ }"
if [[ "$n" -eq 0 ]]; then
	echo "nix-discover: no build targets (empty matrix)."
else
	echo "nix-discover: ${n} build target(s):"
	echo "$targets" | jq -r '.[] | "  - \(.attr)\n      system: \(.system), runner: \(.runner)"'
fi

# Write outputs.
matrix=$(echo "$targets" | jq -c '{"include":.}')
has_targets="false"
[[ "$n" -gt 0 ]] && has_targets="true"
{
	echo "matrix=${matrix}"
	echo "has_targets=${has_targets}"
} >>"$GITHUB_OUTPUT"
