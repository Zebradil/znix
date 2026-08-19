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
