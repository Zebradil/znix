# +==========================+
# | Polkit TTY agent         |
# +--------------------------+

if lib::check_commands pkttyagent; then
  if [[ -t 0 ]]; then
    log::debug "Starting pkttyagent for polkit authentication"
    pkttyagent --process $$ &
    _ZNIX_POLKIT_PID=$!
    disown $_ZNIX_POLKIT_PID
    trap 'kill $_ZNIX_POLKIT_PID 2>/dev/null' EXIT
  fi
fi
