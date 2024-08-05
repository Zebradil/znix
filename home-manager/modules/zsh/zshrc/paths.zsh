# +=========================+
# | PATHs                   |
# +-------------------------+

typeset -TUx PATH path

path=("/opt/homebrew/bin" "${path[@]}")
path=("$WORKSPACE/.local/bin" "${path[@]}")
path=("$HOME/bin" "${path[@]}")
path=("$GOPATH/bin" "${path[@]}")

log::debug "PATH: $PATH"
