usage() {
  cat <<'EOF'
skillsync - sync private skill repos into AI agent skill directories

Usage:
  skillsync status              clone and link state (no network)
  skillsync diff [source]       fetch and show incoming changes
  skillsync apply [-y] [source] update clone(s), link bundles, prune stale

Config: ~/.config/skillsync/config.yaml (override with SKILLSYNC_CONFIG)
Clones: ~/.local/share/skillsync/clones (override with SKILLSYNC_DATA)
EOF
}

CONFIG="${SKILLSYNC_CONFIG:-$HOME/.config/skillsync/config.yaml}"
DATA="${SKILLSYNC_DATA:-$HOME/.local/share/skillsync}"
CLONES="$DATA/clones"

die() {
  echo "skillsync: $*" >&2
  exit 1
}

cfg() { yq -r "$1" "$CONFIG"; }
# $2 is a yq expression using .sources[env(S)]
src_cfg() { S="$1" yq -r "$2" "$CONFIG"; }

list_sources() { cfg '.sources | keys | .[]'; }
list_targets() {
  local t
  while IFS= read -r t; do printf '%s\n' "${t/#\~/$HOME}"; done < <(cfg '.targets[]')
}
src_url() { src_cfg "$1" '.sources[env(S)].url'; }
src_ref() { src_cfg "$1" '.sources[env(S)].ref // "main"'; }
src_include() { src_cfg "$1" '.sources[env(S)].include // [] | .[]'; }

require_config() {
  [ -f "$CONFIG" ] || die "no config at $CONFIG - nothing to do"
  yq -e '((.targets | type) == "!!seq") and ((.targets | length) > 0) and ((.targets | map((type == "!!str") and (length > 0)) | all)) and ((.sources | type) == "!!map") and ((.sources | length) > 0) and (.sources | to_entries | map((.key | length > 0) and ((.value | type) == "!!map") and ((.value.url | type) == "!!str") and ((.value.url | length) > 0) and ((.value.include | type) == "!!seq") and ((.value.include | length) > 0) and (.value.include | map((type == "!!str") and (length > 0)) | all)) | all)' "$CONFIG" >/dev/null || die "config: targets must be non-empty strings; sources need url and non-empty include lists"
}

require_source() {
  [ "$(S="$1" yq -r '.sources | has(env(S))' "$CONFIG")" = "true" ] || die "unknown source: $1"
}

# DESIRED maps bundle name -> source name, across the whole config.
# Prune always works from the full desired set, so a per-source apply
# never touches links owned by other sources.
declare -A DESIRED=()
build_desired() {
  local s b n
  while IFS= read -r s; do
    n=0
    while IFS= read -r b; do
      n=$((n + 1))
      if [ -n "${DESIRED[$b]:-}" ] && [ "${DESIRED[$b]}" != "$s" ]; then
        die "bundle '$b' included by both '${DESIRED[$b]}' and '$s'"
      fi
      DESIRED[$b]="$s"
    done < <(src_include "$s")
    [ "$n" -gt 0 ] || die "source '$s' has an empty include list"
  done < <(list_sources)
}

cmd_status() {
  build_desired
  local s t b src dest ok=0 bad=0
  while IFS= read -r s; do
    if [ -d "$CLONES/$s/.git" ]; then
      echo "$s: $(git -C "$CLONES/$s" log -1 --format='%h %cs %s')"
    else
      echo "$s: not cloned (run: skillsync apply $s)"
    fi
  done < <(list_sources)
  while IFS= read -r t; do
    for b in "${!DESIRED[@]}"; do
      src="${DESIRED[$b]}"
      dest="$CLONES/$src/$b"
      if [ -L "$t/$b" ]; then
        if [ "$(readlink "$t/$b")" = "$dest" ]; then
          ok=$((ok + 1))
        else
          echo "STALE     $t/$b -> $(readlink "$t/$b")"
          bad=$((bad + 1))
        fi
      elif [ -e "$t/$b" ]; then
        echo "CONFLICT  $t/$b exists and is not skillsync-managed"
        bad=$((bad + 1))
      else
        echo "MISSING   $t/$b"
        bad=$((bad + 1))
      fi
    done
  done < <(list_targets)
  echo "links: $ok ok, $bad need attention"
}

cmd_diff() {
  local only="${1:-}" s dir url ref head next
  [ -z "$only" ] || require_source "$only"
  while IFS= read -r s; do
    [ -z "$only" ] || [ "$s" = "$only" ] || continue
    dir="$CLONES/$s"
    ref=$(src_ref "$s")
    echo "== $s ($ref)"
    if [ ! -d "$dir/.git" ]; then
      echo "not cloned - 'skillsync apply $s' will clone $(src_url "$s")"
      continue
    fi
    url=$(src_url "$s")
    git -c "remote.origin.url=$url" -C "$dir" fetch --quiet origin "$ref"
    head=$(git -C "$dir" rev-parse HEAD)
    next=$(git -C "$dir" rev-parse FETCH_HEAD)
    if [ "$head" = "$next" ]; then
      echo "up to date"
      continue
    fi
    if git -C "$dir" merge-base --is-ancestor HEAD FETCH_HEAD; then
      git -C "$dir" --no-pager log --oneline HEAD..FETCH_HEAD
    else
      git -C "$dir" --no-pager log --left-right --oneline HEAD...FETCH_HEAD
    fi
    git -C "$dir" diff HEAD FETCH_HEAD
  done < <(list_sources)
}

update_clone() {
  local s="$1" dir url ref n head next
  dir="$CLONES/$s"
  url=$(src_url "$s")
  ref=$(src_ref "$s")
  if [ ! -d "$dir/.git" ]; then
    mkdir -p "$CLONES"
    git clone --quiet --branch "$ref" "$url" "$dir"
    echo "$s: cloned at $(git -C "$dir" log -1 --format=%h)"
    return
  fi
  git -C "$dir" remote set-url origin "$url"
  git -C "$dir" fetch --quiet origin "$ref"
  head=$(git -C "$dir" rev-parse HEAD)
  next=$(git -C "$dir" rev-parse FETCH_HEAD)
  if [ "$head" = "$next" ]; then
    echo "$s: up to date"
    return
  fi
  if git -C "$dir" merge-base --is-ancestor HEAD FETCH_HEAD; then
    n=$(git -C "$dir" rev-list --count HEAD..FETCH_HEAD)
    git -C "$dir" --no-pager log --oneline HEAD..FETCH_HEAD
  else
    n="rewritten history"
    git -C "$dir" --no-pager log --left-right --oneline HEAD...FETCH_HEAD
  fi
  git -C "$dir" reset --hard --quiet FETCH_HEAD
  echo "$s: updated ($n)"
}

validate_bundles() {
  local b src dest
  for b in "${!DESIRED[@]}"; do
    src="${DESIRED[$b]}"
    dest="$CLONES/$src/$b"
    [ ! -d "$CLONES/$src/.git" ] || { [ -d "$dest" ] && [ -f "$dest/SKILL.md" ]; } || die "source '$src' has no valid bundle '$b'"
  done
}

link_bundles() {
  local t b src dest
  while IFS= read -r t; do
    mkdir -p "$t"
    for b in "${!DESIRED[@]}"; do
      src="${DESIRED[$b]}"
      dest="$CLONES/$src/$b"
      [ -d "$dest" ] || continue
      if [ -L "$t/$b" ]; then
        case "$(readlink "$t/$b")" in
          "$CLONES"/*) ln -sfn "$dest" "$t/$b" ;;
          *) echo "SKIP: $t/$b is a symlink not managed by skillsync" ;;
        esac
      elif [ -e "$t/$b" ]; then
        echo "SKIP: $t/$b exists and is not a symlink"
      else
        ln -s "$dest" "$t/$b"
      fi
    done
  done < <(list_targets)
}

prune() {
  local yes="$1" t e raw name s d known=" " victims=() a
  while IFS= read -r t; do
    [ -d "$t" ] || continue
    for e in "$t"/*; do
      [ -L "$e" ] || continue
      raw=$(readlink "$e")
      case "$raw" in "$CLONES"/*) ;; *) continue ;; esac
      name=$(basename "$e")
      if [ -n "${DESIRED[$name]:-}" ] && [ "$raw" = "$CLONES/${DESIRED[$name]}/$name" ]; then
        continue
      fi
      victims+=("$e")
    done
  done < <(list_targets)

  while IFS= read -r s; do known="$known$s "; done < <(list_sources)
  if [ -d "$CLONES" ]; then
    for d in "$CLONES"/*; do
      [ -d "$d" ] || continue
      case "$known" in
        *" $(basename "$d") "*) ;;
        *) victims+=("$d") ;;
      esac
    done
  fi

  [ "${#victims[@]}" -gt 0 ] || return 0
  echo "prune candidates:"
  printf '  %s\n' "${victims[@]}"
  if [ "$yes" != 1 ]; then
    if [ ! -t 0 ]; then
      echo "not a tty - rerun with -y to prune"
      return 0
    fi
    read -r -p "remove? [y/N] " a
    case "$a" in y | Y) ;; *)
      echo "kept"
      return 0
      ;;
    esac
  fi
  rm -rf "${victims[@]}"
  echo "pruned ${#victims[@]}"
}

cmd_apply() {
  local yes=0 only="" s
  while [ $# -gt 0 ]; do
    case "$1" in
      -y | --yes) yes=1 ;;
      -*) die "unknown flag: $1" ;;
      *) only="$1" ;;
    esac
    shift
  done
  [ -z "$only" ] || require_source "$only"
  build_desired
  while IFS= read -r s; do
    [ -z "$only" ] || [ "$s" = "$only" ] || continue
    update_clone "$s"
  done < <(list_sources)
  validate_bundles
  link_bundles
  prune "$yes"
}

case "${1:-}" in
  status)
    require_config
    cmd_status
    ;;
  diff)
    shift
    require_config
    cmd_diff "$@"
    ;;
  apply)
    shift
    require_config
    cmd_apply "$@"
    ;;
  "" | -h | --help | help)
    usage
    ;;
  *)
    die "unknown command: $1 (see: skillsync --help)"
    ;;
esac
