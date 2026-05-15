#!/usr/bin/bash

INTERNAL="eDP-1"
INTERNAL_SCALE="2.0"
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/hyprland"
STATE_FILE="$STATE_DIR/monitor-switch-state.json"

connected_monitors() {
  local outputs=()
  local card conn_status conn_name

  for card in /sys/class/drm/card*-*; do
    [[ -f "$card/status" ]] || continue
    conn_status=$(<"$card/status")
    conn_name=$(basename "$card" | sed 's/^card[0-9]*-//')
    if [[ $conn_status == "connected" ]]; then
      outputs+=("$conn_name")
    fi
  done

  if [[ ${#outputs[@]} -gt 0 ]]; then
    printf '%s\n' "${outputs[@]}" | sort -u
  fi
}

detect_topology() {
  local outputs=()
  local joined=""
  local output

  mapfile -t outputs < <(connected_monitors)

  for output in "${outputs[@]}"; do
    if [[ -n $joined ]]; then
      joined+=","
    fi
    joined+="$output"
  done

  printf '%s\n' "$joined"
}

load_state() {
  state_preset=""
  state_mode=""
  state_topology=""

  [[ -f $STATE_FILE ]] || return 0

  state_preset=$(jq -r '.preset // empty' "$STATE_FILE" 2>/dev/null)
  state_mode=$(jq -r '.mode // empty' "$STATE_FILE" 2>/dev/null)
  state_topology=$(jq -r '.topology // empty' "$STATE_FILE" 2>/dev/null)
}

save_state() {
  local preset="$1"
  local mode="$2"
  local topology="${3:-$(detect_topology)}"

  mkdir -p "$STATE_DIR"
  jq -n \
    --arg preset "$preset" \
    --arg mode "$mode" \
    --arg topology "$topology" \
    '{ preset: $preset, mode: $mode, topology: $topology }' > "$STATE_FILE.tmp"
  mv "$STATE_FILE.tmp" "$STATE_FILE"
}

valid_preset() {
  case "$1" in
  single|external-only|extended|mirror)
    return 0
    ;;
  *)
    return 1
    ;;
  esac
}

# Detect external monitor name.
# First try hyprctl (works when monitor is active),
# then fall back to DRM sysfs (works even when software-disabled).
detect_external() {
  local name
  name=$(hyprctl monitors all -j | jq -r '[.[] | select(.name != "'"$INTERNAL"'")][0].name // empty')
  if [[ -n $name ]]; then
    echo "$name"
    return
  fi
  while IFS= read -r name; do
    if [[ $name != "$INTERNAL" ]]; then
      echo "$name"
      return
    fi
  done < <(connected_monitors)
}

external=$(detect_external)

# Re-enable a disabled monitor so hyprctl can configure it.
ensure_enabled() {
  local mon="$1" disabled scale="1"
  if [[ $mon == "$INTERNAL" ]]; then
    scale="$INTERNAL_SCALE"
  fi
  disabled=$(hyprctl monitors all -j | jq -r --arg n "$mon" '.[] | select(.name == $n) | .disabled' 2>/dev/null)
  # Only bootstrap when disabled - avoids racing the caller's subsequent
  # hyprctl keyword monitor call, which would otherwise clobber the real scale.
  if [[ $disabled == "true" ]]; then
    hyprctl keyword monitor "$mon, preferred, auto, $scale"
    sleep 0.3
  fi
}

# Bail out with a notification when no external monitor is available.
require_external() {
  if [[ -z $external ]]; then
    notify-send -u critical "Display" "No external monitor detected"
    exit 1
  fi
}

apply_preset() {
  case "$1" in
  single)
    ensure_enabled "$INTERNAL"
    hyprctl keyword monitor "$INTERNAL, preferred, auto, $INTERNAL_SCALE"
    [[ -n $external ]] && hyprctl keyword monitor "$external, disable"
    notify-send "Display" "Single (integrated only)"
    ;;
  external-only)
    require_external
    ensure_enabled "$external"
    hyprctl keyword monitor "$external, preferred, auto, 1"
    hyprctl keyword monitor "$INTERNAL, disable"
    notify-send "Display" "External only"
    ;;
  extended)
    require_external
    ensure_enabled "$external"
    ensure_enabled "$INTERNAL"
    hyprctl keyword monitor "$external, preferred, 0x0, 1"
    hyprctl keyword monitor "$INTERNAL, preferred, auto-down-right, $INTERNAL_SCALE"
    notify-send "Display" "Extended (external + integrated)"
    ;;
  mirror)
    require_external
    ensure_enabled "$external"
    ensure_enabled "$INTERNAL"
    hyprctl keyword monitor "$external, preferred, auto, 1"
    hyprctl keyword monitor "$INTERNAL, preferred, auto, $INTERNAL_SCALE, mirror, $external"
    notify-send "Display" "Mirror"
    ;;
  *)
    echo "Usage: monitor-switch {single|external-only|extended|mirror|--pick|--reconcile}" >&2
    exit 1
    ;;
  esac
}

detect_active() {
  # Use "monitors all" to see mirrored monitors too
  # (mirrored monitors don't appear in plain "monitors").
  local all_json has_internal=false has_external=false is_mirror=false
  all_json=$(hyprctl monitors all -j)

  local entry mon_name mon_mirror mon_disabled
  while IFS= read -r entry; do
    mon_name=$(jq -r '.name' <<<"$entry")
    mon_mirror=$(jq -r '.mirrorOf' <<<"$entry")
    mon_disabled=$(jq -r '.disabled' <<<"$entry")

    [[ $mon_disabled == "true" ]] && continue

    if [[ $mon_name == "$INTERNAL" ]]; then
      has_internal=true
      if [[ $mon_mirror != "none" && -n $mon_mirror && $mon_mirror != "null" ]]; then
        is_mirror=true
      fi
    else
      has_external=true
    fi
  done < <(jq -c '.[]' <<<"$all_json")

  if $is_mirror; then
    echo "mirror"
  elif $has_internal && $has_external; then
    echo "extended"
  elif ! $has_internal && $has_external; then
    echo "external-only"
  else
    echo "single"
  fi
}

reconcile_preset() {
  local preserve_manual="$1"
  local topology desired desired_mode active

  external=$(detect_external)
  topology=$(detect_topology)
  load_state

  if [[ -z $external ]]; then
    desired="single"
    desired_mode="auto"
  elif [[ $preserve_manual == "true" && $state_mode == "manual" && $state_topology == "$topology" ]] && valid_preset "$state_preset"; then
    desired="$state_preset"
    desired_mode="manual"
  else
    desired="external-only"
    desired_mode="auto"
  fi

  active=$(detect_active 2>/dev/null || true)
  if [[ $active != "$desired" ]]; then
    apply_preset "$desired"
  fi
  save_state "$desired" "$desired_mode" "$topology"
}

if [[ "${1:-}" == "--pick" || $# -eq 0 ]]; then
  active=$(detect_active)
  has_external=false
  [[ -n $external ]] && has_external=true

  options=()
  for preset in single external-only extended mirror; do
    if ! $has_external && [[ $preset != "single" ]]; then
      continue
    fi
    if [[ $active == "$preset" ]]; then
      options+=("* $preset")
    else
      options+=("$preset")
    fi
  done

  stdin_lib="$(dirname "$(command -v anyrun)")/../lib/libstdin.so"
  chosen=$(printf '%s\n' "${options[@]}" | anyrun --plugins "$stdin_lib" --show-results-immediately true)
  [[ -z $chosen ]] && exit 0
  # anyrun weirdly duplicates the chosen string
  chosen="${chosen:0:$((${#chosen} / 2))}"
  chosen="${chosen#\* }"
  apply_preset "$chosen"
  save_state "$chosen" "manual"
elif [[ "${1:-}" == "--reconcile" ]]; then
  reconcile_preset true
elif [[ "${1:-}" == "--default" ]]; then
  reconcile_preset false
else
  apply_preset "$1"
  save_state "$1" "manual"
fi
