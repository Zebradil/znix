# +==========================+
# | Emacs                    |
# +--------------------------+

if lib::check_commands emacs; then
  log::debug "Configuring Emacs"

  alias ecc="emacsclient -nc"

  my:emacs() {
    emacs "$@" </dev/null &>/dev/null &
    disown
  }

  my:emacs:update_spacemacs_packages() {
    emacs --batch -l ~/.emacs.d/init.el --eval="(configuration-layer/update-packages t)"
  }
fi
