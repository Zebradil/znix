# +==========================+
# | pyenv                    |
# +--------------------------+

if lib::check_commands pyenv; then
  log::debug "Configuring pyenv"
  eval "$(pyenv init -)"
fi
