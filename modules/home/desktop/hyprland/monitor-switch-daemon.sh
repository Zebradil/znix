#!/usr/bin/bash

set +o pipefail # socat exits with broken pipe on disconnect; that's expected

# LOG_LEVEL controls verbosity: "debug" prints all messages, "info" (default) prints
# only monitor connection/disconnection events and preset changes.
LOG_LEVEL="${LOG_LEVEL:-info}"

log_info()  { echo "[monitor-daemon] $*"; }
log_debug() { [[ $LOG_LEVEL == "debug" ]] && echo "[monitor-daemon] DEBUG: $*" || true; }

INTERNAL=$(monitor-switch --internal-name)

reconcile_monitors() {
  if ! monitor-switch --reconcile; then
    log_info "reconcile failed, forcing single..."
    monitor-switch single || true
  fi
}

handle_external_event() {
  local kind="$1" mon="$2"
  log_info "$kind: $mon, reconciling..."
  sleep 1
  reconcile_monitors
}

log_info "starting daemon, running initial reconciliation..."
reconcile_monitors

while true; do
  socket="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
  log_debug "connecting to socket: $socket"
  socat -U - UNIX-CONNECT:"$socket" 2>/dev/null | while IFS= read -r line; do
    log_debug "IPC event: $line"
    event="${line%%>>*}"
    monitor="${line#*>>}"

    if [[ $event == "configreloaded" ]]; then
      handle_external_event "config reloaded" "n/a"
      continue
    fi

    if [[ $monitor == "$INTERNAL" ]]; then
      log_debug "ignoring event for internal monitor"
      continue
    fi

    case "$event" in
      monitoradded)
        # FALLBACK appears when all real monitors disconnect; reconcile handles it.
        handle_external_event "monitor added" "$monitor"
        ;;
      monitorremoved)
        if [[ $monitor == "FALLBACK" ]]; then
          log_debug "FALLBACK monitor removed, ignoring"
        else
          handle_external_event "monitor removed" "$monitor"
        fi
        ;;
    esac
  done
  log_info "socat disconnected, waiting 2s before reconnect..."
  sleep 2
done
