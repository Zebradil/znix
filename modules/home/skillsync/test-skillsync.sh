#!/usr/bin/env bash
set -euo pipefail

script="$(dirname "$0")/skillsync.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

git init --quiet "$tmp/source"
git -C "$tmp/source" config user.email test@example.com
git -C "$tmp/source" config user.name test
mkdir -p "$tmp/source/skill" "$tmp/home/target"
touch "$tmp/source/skill/SKILL.md"
git -C "$tmp/source" add .
git -C "$tmp/source" commit --quiet -m main
git -C "$tmp/source" branch -M main
git -C "$tmp/source" checkout --quiet -b alternate
git -C "$tmp/source" commit --allow-empty --quiet -m alternate
git clone --quiet --bare "$tmp/source" "$tmp/remote.git"
git clone --quiet --branch main "$tmp/remote.git" "$tmp/data/clones/source"

mkdir -p "$tmp/home/.config/skillsync"
printf '%s\n' \
  'targets:' \
  '  - ~/target' \
  'sources:' \
  '  source:' \
  "    url: $tmp/remote.git" \
  '    ref: alternate' \
  '    include:' \
  '      - skill' \
  > "$tmp/home/.config/skillsync/config.yaml"

output=$(HOME="$tmp/home" SKILLSYNC_DATA="$tmp/data" SKILLSYNC_CONFIG="$tmp/home/.config/skillsync/config.yaml" bash "$script" status)
[[ "$output" == *"REF       source: applied main; config wants alternate (run: skillsync apply source)"* ]]
[[ "$output" == *"refs: 0 ok, 1 need attention"* ]]

HOME="$tmp/home" SKILLSYNC_DATA="$tmp/data" SKILLSYNC_CONFIG="$tmp/home/.config/skillsync/config.yaml" bash "$script" apply -y source
[[ "$(git -C "$tmp/data/clones/source" config --get skillsync.ref)" == alternate ]]

output=$(HOME="$tmp/home" SKILLSYNC_DATA="$tmp/data" SKILLSYNC_CONFIG="$tmp/home/.config/skillsync/config.yaml" bash "$script" status)
[[ "$output" == *"refs: 1 ok, 0 need attention"* ]]

touch "$tmp/source/skill/new-file" "$tmp/source/unrelated-file"
git -C "$tmp/source" add .
git -C "$tmp/source" commit --quiet -m update
git -C "$tmp/source" push --quiet "$tmp/remote.git" alternate

output=$(HOME="$tmp/home" SKILLSYNC_DATA="$tmp/data" SKILLSYNC_CONFIG="$tmp/home/.config/skillsync/config.yaml" bash "$script" status)
[[ "$output" == *"UPDATE    source:"* ]]
[[ "$output" == *"refs: 0 ok, 1 need attention"* ]]

output=$(HOME="$tmp/home" SKILLSYNC_DATA="$tmp/data" SKILLSYNC_CONFIG="$tmp/home/.config/skillsync/config.yaml" bash "$script" diff source)
[[ "$output" == *"skill/new-file"* ]]
[[ "$output" != *"unrelated-file"* ]]

# A source with `path` links bundles from that subdirectory.
git init --quiet "$tmp/nested"
git -C "$tmp/nested" config user.email test@example.com
git -C "$tmp/nested" config user.name test
mkdir -p "$tmp/nested/skills/deep"
touch "$tmp/nested/skills/deep/SKILL.md"
git -C "$tmp/nested" add .
git -C "$tmp/nested" commit --quiet -m main
git -C "$tmp/nested" branch -M main
git clone --quiet --bare "$tmp/nested" "$tmp/nested.git"
printf '%s\n' \
  '  nested:' \
  "    url: $tmp/nested.git" \
  '    path: skills/' \
  '    include:' \
  '      - deep' \
  >> "$tmp/home/.config/skillsync/config.yaml"

HOME="$tmp/home" SKILLSYNC_DATA="$tmp/data" SKILLSYNC_CONFIG="$tmp/home/.config/skillsync/config.yaml" bash "$script" apply -y
[[ "$(readlink "$tmp/home/target/deep")" == "$tmp/data/clones/nested/skills/deep" ]]
[[ -L "$tmp/home/target/skill" ]]

touch "$tmp/nested/skills/deep/new-file" "$tmp/nested/skills/other-file"
git -C "$tmp/nested" add .
git -C "$tmp/nested" commit --quiet -m update
git -C "$tmp/nested" push --quiet "$tmp/nested.git" main

output=$(HOME="$tmp/home" SKILLSYNC_DATA="$tmp/data" SKILLSYNC_CONFIG="$tmp/home/.config/skillsync/config.yaml" bash "$script" diff nested)
[[ "$output" == *"skills/deep/new-file"* ]]
[[ "$output" != *"other-file"* ]]

output=$(HOME="$tmp/home" SKILLSYNC_DATA="$tmp/data" SKILLSYNC_CONFIG="$tmp/home/.config/skillsync/config.yaml" bash "$script" status)
[[ "$output" == *"links: 2 ok, 0 need attention"* ]]
