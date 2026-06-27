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

# Enumerate the requested output types in a SINGLE eval, reading only the
# structure (attribute names + each OS config's system) instead of forcing every
# leaf derivation. `nix flake show --all-systems` evaluates each leaf to report
# its name/type/description, which means instantiating expensive `*-build`
# system toplevels just to learn they exist — tens of seconds. `builtins.attrNames`
# never forces those values, so discovery drops from ~50s to ~1s.
#
# The eval emits, per requested type, one of:
#   { "<system>": { "names": [...] } }   per-system named set (checks, packages, devShells)
#   { "<system>": { "derivation": true } } per-system direct derivation (formatter)
#   { "<host>":   { "system": "<sys>" } }  OS config (nixos/darwin), system resolved from the config
#   null                                   the type is absent from the flake
# A node that fails to evaluate becomes { "error": true } and is skipped.
#
# getFlake is used (not `nix flake show`) so all types resolve in one process.
# It only reads attribute names and each OS config's host platform, so an
# uncommitted working tree (which would change store paths but not this
# structure) does not affect the result.
discover_err=$(mktemp)
# The --expr argument is a Nix program, deliberately single-quoted; getEnv reads
# TYPES at eval time, so no shell expansion is wanted here.
# shellcheck disable=SC2016
if ! flake_json=$(
	TYPES=$(printf '%s\n' "${DISCOVERY_TYPES:?DISCOVERY_TYPES is required}" | jq -R . | jq -sc 'map(select(length > 0))') \
		nix eval --json --impure --expr '
		let
			flake = builtins.getFlake (builtins.toString ./.);
			types = builtins.fromJSON (builtins.getEnv "TYPES");
			isOs = t: t == "nixosConfigurations" || t == "darwinConfigurations";
			describeNode = t: _name: v:
				let r = builtins.tryEval (
					if isOs t then { system = v.config.nixpkgs.hostPlatform.system; }
					else if (v.type or "") == "derivation" then { derivation = true; }
					else { names = builtins.attrNames v; });
				in if r.success then r.value else { error = true; };
			describeType = t:
				let node = flake.${t} or null;
				in if node == null then null else builtins.mapAttrs (describeNode t) node;
		in builtins.listToAttrs (map (t: { name = t; value = describeType t; }) types)
	' 2>"$discover_err"
); then
	echo "::error::nix-discover: failed to evaluate flake outputs"
	cat "$discover_err" >&2
	rm -f "$discover_err"
	exit 1
fi
rm -f "$discover_err"

if [[ "${NIX_DISCOVER_DEBUG:-}" =~ ^(1|true|yes)$ ]]; then
	echo "nix-discover: debug enabled, dumping discovered structure"
	echo "$flake_json" | jq .
fi

for type in ${DISCOVERY_TYPES:?DISCOVERY_TYPES is required}; do
	type_json=$(echo "$flake_json" | jq --arg t "$type" '.[$t]')
	if [[ "$type_json" == "null" ]]; then
		echo "::warning::nix-discover: type '$type' not found in flake output, skipping"
		continue
	fi

	case "$type" in
	nixosConfigurations | darwinConfigurations)
		# Keys are host names; each node carries the resolved target system.
		while read -r name sys; do
			add_os_target "$type" "$name" "$sys" "config.system.build.toplevel"
		done < <(echo "$type_json" | jq -r '
			to_entries[]
			| select(.value.error != true)
			| "\(.key) \(.value.system)"
		')
		;;
	*)
		# Per-system type. A node is either a direct derivation (formatter) or a
		# named set of derivations (checks, packages, devShells).
		while read -r sys; do
			node=$(echo "$type_json" | jq --arg s "$sys" '.[$s]')

			if echo "$node" | jq -e '.error == true' >/dev/null 2>&1; then
				echo "::warning::nix-discover: ${type}.${sys} failed to evaluate, skipping"
				continue
			fi

			if echo "$node" | jq -e '.derivation == true' >/dev/null 2>&1; then
				add_os_target "$type" "$sys" "$sys"
			else
				while read -r name; do
					add_os_target "$type" "$sys.$name" "$sys"
				done < <(echo "$node" | jq -r '.names[]')
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
