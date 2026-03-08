# +==========================+
# | Gnome keyring            |
# +--------------------------+

if lib::check_commands gnome-keyring-daemon; then
  log::debug "Configuring gnome-keyring environment"

  if pgrep -f gnome-keyring-daemon >/dev/null; then
    ORIG_SSH_AUTH_SOCK="$SSH_AUTH_SOCK"
    eval "$(gnome-keyring-daemon --start)"
    export GNOME_KEYRING_CONTROL
    # Do not override SSH_AUTH_SOCK if it was already set
    if [[ -z "$ORIG_SSH_AUTH_SOCK" ]]; then
      export SSH_AUTH_SOCK
    fi
  fi
fi

if lib::check_commands systemd-ask-password; then
  log::debug "Configuring gnome-keyring functions"

  my:gnome-keyring:is-locked() {
    keyring_locked="$(
      qdbus \
        org.gnome.keyring \
        /org/freedesktop/secrets/collection/login \
        org.freedesktop.Secret.Collection.Locked
    )"
    if [[ $keyring_locked == "true" ]]; then
      return 0
    else
      return 1
    fi
  }

  my:gnome-keyring:unlock() {
    if my:gnome-keyring:is-locked; then
      if systemd-ask-password | unlock.py; then
        log::info "Unlocked gnome-keyring"
      else
        log::error "Failed to unlock gnome-keyring"
      fi
    fi
  }
fi
