# +=========================+
# | PATHs                   |
# +-------------------------+

typeset -TUx PATH path

path=("/opt/homebrew/bin" "${path[@]}")
path=("${WORKSPACE:?}/.local/bin" "${path[@]}")
# deprecated, use .local/bin instead
path=("${HOME:?}/bin" "${path[@]}")

log::debug "PATH: $PATH"
