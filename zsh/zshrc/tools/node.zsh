# +===============================+
# | Node ecosystem configurations |
# +-------------------------------+

if lib::check_commands npm; then
  log::debug "Configuring local npm packages"
  NPM_PACKAGES="${HOME}/.local/lib/npm_packages"
  export PATH="$NPM_PACKAGES/bin:$PATH"
  NO_UPDATE_NOTIFIER=1 npm config set prefix "$NPM_PACKAGES"

  # Unset manpath so we can inherit from /etc/manpath via the `manpath` command
  unset MANPATH # delete if you already modified MANPATH elsewhere in your config
  MANPATH="$NPM_PACKAGES/share/man:$(manpath)"
  export MANPATH
fi
