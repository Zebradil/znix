#!/usr/bin/bash

set +o pipefail # socat exits with broken pipe on disconnect; that's expected

INTERNAL="eDP-1"
# LOG_LEVEL controls verbosity: "debug" prints all messages, "info" (default) prints
# only monitor connection/disconnection events and preset changes.
LOG_LEVEL="${LOG_LEVEL:-info}"

log_info() { echo "[monitor-daemon] $*"; }
log_debug() { [[ $LOG_LEVEL == "debug" ]] && echo "[monitor-daemon] DEBUG: $*" || true; }

ensure_internal() {
  log_debug "ensure_internal: checking active monitors..."
  local active
  active=$(hyprctl monitors -j 2>/dev/null)
  log_debug "ensure_internal: active monitors: $active"
  if ! jq -r '.[].name' <<< "$active" 2>/dev/null | grep -q "^${INTERNAL}$"; then
    log_info "internal monitor $INTERNAL not active, re-enabling..."
    local result
    result=$(hyprctl keyword monitor "$INTERNAL, preferred, auto, 2.0" 2>&1)
    log_debug "ensure_internal: hyprctl result: $result"
    notify-send "Display" "Single (integrated only)" || true
  else
    log_debug "ensure_internal: $INTERNAL already active, nothing to do"
  fi
}

reconcile_monitors() {
  if ! monitor-switch --reconcile; then
    log_info "reconcile failed; ensuring internal display is on..."
    ensure_internal
  fi
}

while true; do
  socket="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
  log_debug "connecting to socket: $socket"
  socat -U - UNIX-CONNECT:"$socket" 2>/dev/null | while IFS= read -r line; do
    log_debug "IPC event: $line"
    event="${line%%>>*}"
    monitor="${line#*>>}"
    if [[ $monitor == "$INTERNAL" ]]; then
      log_debug "ignoring event for internal monitor"
      continue
    fi
    case "$event" in
      monitoradded)
        if [[ $monitor == "FALLBACK" ]]; then
          # FALLBACK means all real monitors are gone - re-enable internal
          log_info "FALLBACK monitor appeared, re-enabling internal display..."
          sleep 1
          reconcile_monitors
        else
          log_info "external monitor added: $monitor, reconciling preset..."
          sleep 1
          reconcile_monitors
        fi
        ;;
      monitorremoved)
        if [[ $monitor == "FALLBACK" ]]; then
          log_debug "FALLBACK monitor removed, ignoring"
        else
          log_info "external monitor removed: $monitor, reconciling preset..."
          sleep 1
          reconcile_monitors
        fi
        ;;
    esac
  done
  log_info "socat disconnected, waiting 2s before reconnect..."
  sleep 2
done
