# vim: set filetype=zsh shiftwidth=2 softtabstop=2 expandtab:

tabs -4

export WORKSPACE="${WORKSPACE:-$HOME}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$WORKSPACE/.cache}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$WORKSPACE/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$WORKSPACE/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$WORKSPACE/.local/state}"

for f in "${ZDOTDIR:?}/zshrc/lib/"*.zsh; do
    source "$f"
done

source "${ZDOTDIR:?}/zshrc/paths.zsh"

# +=========================+
# | Shell configuration     |
# +-------------------------+

setopt autocd extendedglob
bindkey -v

autoload -U edit-command-line
zle -N edit-command-line

bindkey -M vicmd v edit-command-line

read -r -d '' TIMEFMT <<-EOF
    %J   %U  user %S system %P cpu %*E total
    avg shared (code):         %X KB
    avg unshared (data/stack): %D KB
    total (sum):               %K KB
    max memory:                %M MB
    page faults from disk:     %F
    other page faults:         %R
EOF
export TIMEFMT

GPG_TTY=$(tty)
export GPG_TTY

# Iterate over all files in the tools directory and source them
# `(N.,@)` is a glob qualifier that selects all files in the directory:
#   - `N` allows the pattern to match zero times (NULL_GLOB)
#   - `.` selects regular files
#   - `,` separates the `.` and `@` qualifiers
#   - `@` selects links
foreach f ("${ZDOTDIR:?}/zshrc/tools/"*.zsh(N.,@)) { source "$f" }

bindkey -M viins '^[[A' history-beginning-search-backward
bindkey -M vicmd '^[[A' history-beginning-search-backward
bindkey -M viins '^[[B' history-beginning-search-forward
bindkey -M vicmd '^[[B' history-beginning-search-forward

source "${ZDOTDIR:?}/zshrc/aliases-and-functions.zsh"

# +=========================+
# | Local overrides         |
# +-------------------------+

[[ -r "${WORKSPACE:?}/.zshrc.local" ]] && source ${WORKSPACE:?}/.zshrc.local
