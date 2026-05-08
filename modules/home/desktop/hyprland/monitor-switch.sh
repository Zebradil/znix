#!/usr/bin/bash

INTERNAL="eDP-1"
INTERNAL_SCALE="2.0"

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
  for card in /sys/class/drm/card*-*; do
    local conn_status conn_name
    conn_status=$(<"$card/status" 2>/dev/null) || continue
    conn_name=$(basename "$card" | sed 's/^card[0-9]*-//')
    if [[ $conn_status == "connected" && $conn_name != "$INTERNAL" ]]; then
      echo "$conn_name"
      return
    fi
  done
}

external=$(detect_external)

# Re-enable a disabled monitor so hyprctl can configure it.
ensure_enabled() {
  local mon="$1" disabled scale="1"
  if [[ $mon == "$INTERNAL" ]]; then
    scale="$INTERNAL_SCALE"
  fi
  disabled=$(hyprctl monitors all -j | jq -r --arg n "$mon" '.[] | select(.name == $n) | .disabled' 2>/dev/null)
  # Only bootstrap when disabled — avoids racing the caller's subsequent
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
    echo "Usage: monitor-switch {single|external-only|extended|mirror|--pick}" >&2
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
else
  apply_preset "$1"
fi
