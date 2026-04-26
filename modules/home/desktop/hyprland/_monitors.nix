{ pkgs, inputs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  anyrunPkgs = inputs.anyrun.packages.${system};
  anyrunBin = "${anyrunPkgs.anyrun}/bin/anyrun";
  stdinLib = "${anyrunPkgs.stdin}/lib/libstdin.so";

  # See _anyrun.nix for the full explanation. This is a separate minimal
  # Anyrun picker config for monitor selection, not the same derivation.
  pickerConfigDir = pkgs.symlinkJoin {
    name = "anyrun-picker-config";
    paths = [
      (pkgs.writeTextDir "anyrun/config.ron" ''
        Config(
          plugins: ["${stdinLib}"],
          show_results_immediately: true,
          close_on_click: true,
          hide_plugin_info: true,
        )
      '')
    ];
  };

  monitor-switch = pkgs.writeShellApplication {
    name = "monitor-switch";
    runtimeInputs = with pkgs; [
      hyprland
      jq
      libnotify
    ];
    text = ''
      INTERNAL="eDP-1"
      INTERNAL_SCALE="1.5"

      # Detect external monitor name.
      # First try hyprctl (works when monitor is active),
      # then fall back to DRM sysfs (works even when software-disabled).
      detect_external() {
        name=$(hyprctl monitors all -j | jq -r '[.[] | select(.name != "'"$INTERNAL"'")][0].name // empty')
        if [ -n "$name" ]; then
          echo "$name"
          return
        fi
        for card in /sys/class/drm/card*-*; do
          conn_status=$(cat "$card/status" 2>/dev/null)
          conn_name=$(basename "$card" | sed 's/^card[0-9]*-//')
          if [ "$conn_status" = "connected" ] && [ "$conn_name" != "$INTERNAL" ]; then
            echo "$conn_name"
            return
          fi
        done
      }

      external=$(detect_external)

      # Re-enable a disabled monitor so hyprctl can configure it
      ensure_enabled() {
        local mon="$1"
        hyprctl keyword monitor "$mon, preferred, auto, 1"
        sleep 0.3
      }

      apply_preset() {
        case "$1" in
          single)
            ensure_enabled "$INTERNAL"
            hyprctl keyword monitor "$INTERNAL, preferred, auto, $INTERNAL_SCALE"
            [ -n "$external" ] && hyprctl keyword monitor "$external, disable"
            notify-send "Display" "Single (integrated only)"
            ;;
          external-only)
            [ -z "$external" ] && { notify-send -u critical "Display" "No external monitor detected"; exit 1; }
            ensure_enabled "$external"
            hyprctl keyword monitor "$external, preferred, auto, 1"
            hyprctl keyword monitor "$INTERNAL, disable"
            notify-send "Display" "External only"
            ;;
          extended)
            [ -z "$external" ] && { notify-send -u critical "Display" "No external monitor detected"; exit 1; }
            ensure_enabled "$external"
            ensure_enabled "$INTERNAL"
            hyprctl keyword monitor "$external, preferred, 0x0, 1"
            hyprctl keyword monitor "$INTERNAL, preferred, auto-down-right, $INTERNAL_SCALE"
            notify-send "Display" "Extended (external + integrated)"
            ;;
          mirror)
            [ -z "$external" ] && { notify-send -u critical "Display" "No external monitor detected"; exit 1; }
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
        # (mirrored monitors don't appear in plain "monitors")
        all_json=$(hyprctl monitors all -j)
        has_internal=false
        has_external=false
        is_mirror=false
        while IFS= read -r entry; do
          mon_name=$(echo "$entry" | jq -r '.name')
          mon_mirror=$(echo "$entry" | jq -r '.mirrorOf')
          mon_disabled=$(echo "$entry" | jq -r '.disabled')
          # Skip disabled monitors
          [ "$mon_disabled" = "true" ] && continue
          if [ "$mon_name" = "$INTERNAL" ]; then
            has_internal=true
            # mirrorOf is "none" when not mirroring, or a monitor ID when mirroring
            if [ "$mon_mirror" != "none" ] && [ "$mon_mirror" != "" ] && [ "$mon_mirror" != "null" ]; then
              is_mirror=true
            fi
          else
            has_external=true
          fi
        done < <(echo "$all_json" | jq -c '.[]')
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

      if [ "''${1:-}" = "--pick" ] || [ $# -eq 0 ]; then
        active=$(detect_active)
        has_external=false
        [ -n "$external" ] && has_external=true
        options=""
        for preset in single external-only extended mirror; do
          # Skip external-dependent presets if no external display is physically connected
          if ! $has_external && [ "$preset" != "single" ]; then
            continue
          fi
          if [ "$active" = "$preset" ]; then
            options="''${options}* $preset
"
          else
            options="''${options}$preset
"
          fi
        done
        chosen=$(printf '%s' "$options" | XDG_CONFIG_HOME="${pickerConfigDir}" ${anyrunBin})
        [ -z "$chosen" ] && exit 0
        # Strip the active marker before applying
        chosen="''${chosen#\* }"
        apply_preset "$chosen"
      else
        apply_preset "$1"
      fi
    '';
  };

  monitor-switch-daemon = pkgs.writeShellApplication {
    name = "monitor-switch-daemon";
    runtimeInputs = [
      monitor-switch
      pkgs.socat
      pkgs.hyprland
      pkgs.jq
      pkgs.libnotify
    ];
    excludeShellChecks = [ "SC2312" ];
    text = ''
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
          event="''${line%%>>*}"
          monitor="''${line#*>>}"
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
    '';
  };
in
{
  home.packages = [
    monitor-switch
  ];

  wayland.windowManager.hyprland.settings.bind = [
    "$mod, P, exec, hypr-exec monitor-switch --pick"
  ];

  systemd.user.services.monitor-switch-daemon = {
    Unit = {
      Description = "Auto-switch display preset on monitor plug/unplug";
      After = [ "hyprland-session.target" ];
    };
    Service = {
      ExecStart = "${monitor-switch-daemon}/bin/monitor-switch-daemon";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "hyprland-session.target" ];
  };
}
