# +=========================+
# | PATHs                   |
# +-------------------------+

typeset -TUx PATH path

path=("$HOME/.cargo/bin" "${path[@]}")
path=("$HOME/.config/composer/vendor/bin" "${path[@]}")
path=("$HOME/.krew/bin" "${path[@]}")
path=("$HOME/.local/bin" "${path[@]}")
path=("$HOME/go/bin" "${path[@]}")
path=("$HOME/bin" "${path[@]}")

log::debug "PATH: $PATH"
