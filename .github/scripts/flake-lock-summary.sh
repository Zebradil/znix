#!/usr/bin/env bash

set -euo pipefail

# Usage: flake-lock-summary.sh <old-lock-file> <new-lock-file>
#
# Compares two flake.lock files and outputs a Markdown summary of changed
# direct inputs (those listed under the root node), with GitHub compare links.
# Transitive dependency changes are intentionally excluded.

old_lock="${1:?Usage: flake-lock-summary.sh <old-lock-file> <new-lock-file>}"
new_lock="${2:?Usage: flake-lock-summary.sh <old-lock-file> <new-lock-file>}"

jq -r -n \
	--slurpfile old "$old_lock" \
	--slurpfile new "$new_lock" \
	'
	# Direct inputs are the root node inputs whose value is a string (node name).
	# "follows" entries are arrays like ["nixpkgs"] and are skipped.
	($old[0].nodes.root.inputs | to_entries | map(select(.value | type == "string"))) as $old_roots |
	($new[0].nodes.root.inputs | to_entries | map(select(.value | type == "string"))) as $new_roots |

	# Build lookup maps: input_name -> node_name for both old and new
	($old_roots | map({key: .key, value: .value}) | from_entries) as $old_map |
	($new_roots | map({key: .key, value: .value}) | from_entries) as $new_map |

	# Collect all input names that exist in both lock files
	[($old_map | keys[]), ($new_map | keys[])] | unique | sort |
	map(select($old_map[.] != null and $new_map[.] != null)) |

	# For each common input, compare revisions
	map(. as $name |
		($old[0].nodes[$old_map[$name]].locked // null) as $old_locked |
		($new[0].nodes[$new_map[$name]].locked // null) as $new_locked |
		select($old_locked != null and $new_locked != null) |
		select($old_locked.rev != $new_locked.rev) |
		{
			name: $name,
			old_rev: $old_locked.rev,
			new_rev: $new_locked.rev,
			old_short: $old_locked.rev[:7],
			new_short: $new_locked.rev[:7],
			type: ($new_locked.type // ""),
			owner: ($new_locked.owner // ""),
			repo: ($new_locked.repo // ""),
			ref: ($new[0].nodes[$new_map[$name]].original.ref // null)
		}
	) |

	if length == 0 then
		"No direct input changes detected."
	else
		map(
			if .type == "github" then
				"- **\(.name)**" +
				(if .ref then " (`\(.ref)`)" else "" end) +
				": [`\(.old_short)...\(.new_short)`](https://github.com/\(.owner)/\(.repo)/compare/\(.old_rev)...\(.new_rev))"
			else
				"- **\(.name)**" +
				(if .ref then " (`\(.ref)`)" else "" end) +
				": `\(.old_short)...\(.new_short)`"
			end
		) | join("\n")
	end
	'
