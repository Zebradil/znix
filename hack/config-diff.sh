#!/usr/bin/env bash
# Unified diff of the *configuration files* between the active generation and a
# freshly built one: what actually lands in etc/, Library/ (launchd plists),
# home-files/, ... Package version churn is `nvd diff`'s job.
#
# Store hashes are normalised away by default, so a dependency rebuild that
# leaves the config text identical produces no output at all. Output is
# git-style unified diff, ready for delta/riff/diff-so-fancy.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: config-diff.sh [options] [PATH...]

Options:
  -t, --target system|home|both  what to diff (default: system)
  -f, --flake REF                flake ref (default: .)
  -n, --name NAME                host for system, user@host for home
  -a, --attr ATTR                full flake attribute, overrides --name
  -c, --current PATH             tree to compare against (default: active generation)
  -x, --exclude NAME             extra directory/file basename to skip (repeatable)
  -H, --keep-hashes              do not normalise /nix/store/<hash>- prefixes
  -h, --help

PATH... are paths relative to the generation root (etc/ssh,
home-files/.config/nvim, ...); without them the whole tree is compared.

Examples:
  config-diff.sh                             # system config changes
  config-diff.sh -t home | delta             # home-manager config changes
  config-diff.sh -t home home-files/.config/git
  config-diff.sh -n tuxedo etc               # another host in this flake
USAGE
}

flake=.
target=system
attr=
name=
current=
keep_hashes=
excludes=()
paths=()

while (($#)); do
  case $1 in
  -t | --target) target=$2 && shift 2 ;;
  -f | --flake) flake=$2 && shift 2 ;;
  -n | --name) name=$2 && shift 2 ;;
  -a | --attr) attr=$2 && shift 2 ;;
  -c | --current) current=$2 && shift 2 ;;
  -x | --exclude) excludes+=("$2") && shift 2 ;;
  -H | --keep-hashes) keep_hashes=1 && shift ;;
  -h | --help) usage && exit 0 ;;
  --) shift && paths+=("$@") && break ;;
  -*) usage >&2 && exit 2 ;;
  *) paths+=("$1") && shift ;;
  esac
done

if [[ $target == both ]]; then
  for t in system home; do
    "$0" -t "$t" -f "$flake" ${keep_hashes:+-H} -- ${paths[@]+"${paths[@]}"}
  done
  exit 0
fi

host=$(hostname -s)
case $target in
system)
  # nix-darwin stamps its generations; anything else here is NixOS.
  if [[ -e /run/current-system/darwin-version ]]; then kind=darwinConfigurations; else kind=nixosConfigurations; fi
  : "${name:=$host}"
  : "${attr:=$kind.\"$name\".system}"
  : "${current:=/run/current-system}"
  skip=(sw Applications Fonts)
  ;;
home)
  : "${name:=$USER@$host}"
  : "${attr:=homeConfigurations.\"$name\".activationPackage}"
  : "${current:=${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/home-manager}"
  skip=(home-path)
  ;;
*)
  usage >&2
  exit 2
  ;;
esac

[[ -d $current ]] || { echo "config-diff: no current generation at $current" >&2 && exit 1; }

new=$(nix build --no-link --print-out-paths "$flake#$attr")

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# The link names give the a/ and b/ prefixes for free.
ln -s "$(cd "$current" && pwd -P)" "$tmp/a"
ln -s "$new" "$tmp/b"
cd "$tmp"

roots=(.)
((${#paths[@]})) && roots=("${paths[@]/#/./}")

prune=()
for x in "${skip[@]}" ${excludes[@]+"${excludes[@]}"}; do prune+=(-name "$x" -prune -o); done

list() (
  cd "$1" || return 0
  # A root missing on this side is normal (file added or removed), not an error.
  find -L "${roots[@]}" ${prune[@]+"${prune[@]}"} -type f -print 2>/dev/null | sed 's|^\./||' || true
)

norm() {
  if [[ $keep_hashes ]]; then cat "$1"; else sed 's|/nix/store/[a-z0-9]\{32\}-|/nix/store/HASH-|g' "$1"; fi
}

is_text() { [[ $1 == /dev/null || ! -s $1 ]] || grep -Iq . "$1"; }

{
  list a
  list b
} | sort -u | while IFS= read -r p; do
  af=a/$p bf=b/$p
  [[ -e $af ]] || af=/dev/null
  [[ -e $bf ]] || bf=/dev/null
  cmp -s "$af" "$bf" && continue

  if is_text "$af" && is_text "$bf"; then
    out=$(diff -u --label "a/$p" --label "b/$p" <(norm "$af") <(norm "$bf")) || true
    [[ -n $out ]] || continue # differed only in store hashes
    printf 'diff --git a/%s b/%s\n%s\n' "$p" "$p" "$out"
  else
    printf 'diff --git a/%s b/%s\nBinary files a/%s and b/%s differ\n' "$p" "$p" "$p" "$p"
  fi
done
