# +==========================+
# | Direnv configuration     |
# +--------------------------+

if lib::check_commands direnv; then
  log::debug "Configuring direnv"
  eval "$(direnv hook zsh)"
fi
