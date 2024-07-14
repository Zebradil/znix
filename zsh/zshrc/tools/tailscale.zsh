# +==========================+
# | Tailscale                |
# +--------------------------+

if lib::check_commands tailscale; then
  log::debug "Configuring tailscale aliases"
  my:tailscale:switch() {
    local tailnet="$1"
    log::info "Switching to tailscale networks requires sudo"
    sudo --validate
    if [[ -z $tailnet ]]; then
      tailnet=$(sudo tailscale switch --list | tail -n +2 | fzf | awk '{print $1}')
      if [[ -z $tailnet ]]; then
        log::error "No network selected"
        return 1
      fi
    fi
    sudo tailscale switch "$tailnet"
  }

  alias tssw=my:tailscale:switch
fi
