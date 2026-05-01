set +o pipefail  # socat exits with broken pipe on disconnect; that's expected
INTERNAL="eDP-1"

log() { echo "[monitor-daemon] $*"; }

ensure_internal() {
  log "ensure_internal: checking active monitors..."
  active=$(hyprctl monitors -j 2>/dev/null)
  log "ensure_internal: active monitors: $active"
  if ! echo "$active" | jq -r '.[].name' 2>/dev/null | grep -q "^$INTERNAL$"; then
    log "ensure_internal: $INTERNAL not active, re-enabling..."
    result=$(hyprctl keyword monitor "$INTERNAL, preferred, auto, 1.5" 2>&1)
    log "ensure_internal: hyprctl result: $result"
    notify-send "Display" "Single (integrated only)" || true
  else
    log "ensure_internal: $INTERNAL already active, nothing to do"
  fi
}

while true; do
  socket="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
  log "connecting to socket: $socket"
  socat -U - UNIX-CONNECT:"$socket" 2>/dev/null | while IFS= read -r line; do
    log "IPC event: $line"
    event="${line%%>>*}"
    monitor="${line#*>>}"
    if [ "$monitor" = "$INTERNAL" ]; then
      log "ignoring event for internal monitor"
      continue
    fi
    case "$event" in
      monitoradded)
        if [ "$monitor" = "FALLBACK" ]; then
          # FALLBACK means all real monitors are gone — re-enable internal
          log "FALLBACK monitor appeared, re-enabling internal display..."
          sleep 1
          ensure_internal
        else
          log "external monitor added: $monitor, switching to external-only in 1s..."
          sleep 1
          monitor-switch external-only
        fi
        ;;
      monitorremoved)
        if [ "$monitor" = "FALLBACK" ]; then
          log "FALLBACK monitor removed, ignoring"
        else
          log "external monitor removed: $monitor, ensuring internal is on in 1s..."
          sleep 1
          ensure_internal
        fi
        ;;
    esac
  done
  log "socat disconnected, ensuring internal display is on in 2s..."
  sleep 2
  ensure_internal
done
