# +===========================+
# | Parallel execution with   |
# | in-place progress display |
# +---------------------------+

# Runs a callback function in parallel for each item, showing docker-pull-style
# in-place progress. Supports a configurable concurrency limit.
#
# Usage:
#   lib::parallel::run [-j <max_jobs>] -c <callback_function> -- <item1> <item2> ...
#
# Options:
#   -j N    Max simultaneous jobs (default: $ZNIX_PARALLEL_JOBS or 0 for unlimited)
#   -c func Callback function, called as `func <item>` in a subshell per item
#
# The callback's stdout is not captured (callers handle their own redirection).
# The callback's stderr is captured to prevent progress display corruption;
# stderr from failed jobs is printed after all jobs complete.
#
# Returns 0 if all items succeed, 1 if any fail, 130 if interrupted.
function lib::parallel::run() {
  setopt localoptions localtraps NO_NOTIFY NO_MONITOR

  # ---- Argument parsing ----
  local max_jobs=${ZNIX_PARALLEL_JOBS:-0}
  local callback=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      -j) max_jobs=$2; shift 2 ;;
      -c) callback=$2; shift 2 ;;
      --) shift; break ;;
      *)  break ;;
    esac
  done

  if [[ -z $callback ]]; then
    log::error "lib::parallel::run: -c <callback> required"
    return 1
  fi
  if (( $# == 0 )); then
    log::warn "No items to process"
    return 0
  fi

  local -a items=("$@")
  local total=${#items}

  # ---- ANSI detection ----
  local use_ansi=0
  if [[ -t 2 ]] && (( total <= ${LINES:-24} - 2 )); then
    use_ansi=1
  fi

  # ---- Temp dir for stderr capture ----
  local tmpdir
  tmpdir=$(mktemp -d)

  # ---- State tracking ----
  local -A pid_to_idx
  local -a item_status
  local -a item_rc
  local running=0
  local completed=0

  for (( i = 1; i <= total; i++ )); do
    item_status[$i]="waiting"
    item_rc[$i]=-1
  done

  # ---- Display column width ----
  local max_name_len=0
  for item in "${items[@]}"; do
    (( ${#item} > max_name_len )) && max_name_len=${#item}
  done
  (( max_name_len > 40 )) && max_name_len=40

  # ---- Signal handling ----
  local _interrupted=0
  trap '_interrupted=1' INT TERM HUP

  _lib_parallel_cleanup() {
    local pid
    for pid in ${(k)pid_to_idx}; do
      kill "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
    done
    (( use_ansi )) && printf '\e[?25h' >&2
    rm -rf "$tmpdir"
  }
  trap '_lib_parallel_cleanup' EXIT

  # ---- Render functions ----
  _lib_parallel_render_line() {
    local name=$1
    local statuss=$2 # status is a reserved word in zsh
    local display="${name:0:40}"
    local color="" symbol=""
    case $statuss in
      waiting)  color=$LOGGER_COLOR_DEBUG  symbol=""   ;;
      running*) color=$LOGGER_COLOR_WARN   symbol=""   ;;
      done)     color=$LOGGER_COLOR_INFO   symbol=" ✓" ;;
      FAILED*)  color=$LOGGER_COLOR_ERROR  symbol=" ✗" ;;
    esac
    printf "  %-${max_name_len}s  %b%s%b%s\n" "$display" "$color" "$statuss" "$LOGGER_COLOR_RESET" "$symbol"
  }

  local _drawn=0

  _lib_parallel_draw_all() {
    if (( use_ansi )); then
      (( _drawn )) && printf '\e[%dA' "$total" >&2
      local i
      for (( i = 1; i <= total; i++ )); do
        printf '\e[2K' >&2
        _lib_parallel_render_line "${items[$i]}" "${item_status[$i]}" >&2
      done
      _drawn=1
    fi
  }

  _lib_parallel_draw_initial() {
    if (( use_ansi )); then
      printf '\e[?25l' >&2
      _lib_parallel_draw_all
    else
      if (( max_jobs == 0 )); then
        log::info "Processing ${total} items in parallel..."
      else
        log::info "Processing ${total} items (max ${max_jobs} parallel)..."
      fi
    fi
  }

  _lib_parallel_notify() {
    if (( ! use_ansi )); then
      local idx=$1
      local item=${items[$idx]}
      local statuss=${item_status[$idx]} # status is a reserved word in zsh
      if [[ $statuss == "done" ]]; then
        log::info "${item}: done"
      else
        log::error "${item}: ${statuss}"
      fi
    fi
  }

  # ---- Completion checker ----
  _lib_parallel_check_completed() {
    local changed=0 pid idx rc
    for pid idx in "${(@kv)pid_to_idx}"; do
      if ! kill -0 "$pid" 2>/dev/null; then
        wait "$pid" 2>/dev/null
        rc=$?
        item_rc[$idx]=$rc
        if (( rc == 0 )); then
          item_status[$idx]="done"
        else
          item_status[$idx]="FAILED (exit $rc)"
        fi
        unset "pid_to_idx[$pid]"
        (( running-- ))
        (( completed++ ))
        _lib_parallel_notify "$idx"
        changed=1
      fi
    done
    (( changed )) && _lib_parallel_draw_all
  }

  # ---- Main execution loop ----
  _lib_parallel_draw_initial

  local idx
  for (( idx = 1; idx <= total; idx++ )); do
    while (( running >= max_jobs )) && (( max_jobs > 0 )); do
      (( _interrupted )) && break 2
      _lib_parallel_check_completed
      (( running >= max_jobs )) && sleep 0.1
    done
    (( _interrupted )) && break

    item_status[$idx]="running..."
    _lib_parallel_draw_all

    (
      set -euo pipefail
      "$callback" "${items[$idx]}" 2>"$tmpdir/stderr.${idx}"
    ) &
    pid_to_idx[$!]=$idx
    (( running++ ))
  done

  # Wait for all remaining jobs
  while (( completed < total && ! _interrupted )); do
    _lib_parallel_check_completed
    (( completed < total )) && sleep 0.1
  done

  # ---- Final output ----
  (( use_ansi )) && printf '\e[?25h' >&2

  local failed=0
  local i
  for (( i = 1; i <= total; i++ )); do
    if [[ ${item_status[$i]} == FAILED* ]]; then
      (( failed++ ))
      if [[ -s "$tmpdir/stderr.${i}" ]]; then
        log::error "--- stderr from ${items[$i]} ---"
        cat "$tmpdir/stderr.${i}" >&2
      fi
    fi
  done

  if (( _interrupted )); then
    log::warn "Interrupted. ${completed}/${total} items completed."
    return 130
  elif (( failed > 0 )); then
    log::error "${failed}/${total} items failed"
    return 1
  else
    log::success "All ${total} items completed successfully"
    return 0
  fi
}
