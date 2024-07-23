# +==========================+
# | Starship prompt          |
# +--------------------------+

if lib::check_commands starship; then
  log::debug "Configuring starship"
  eval "$(starship init zsh)"
fi
