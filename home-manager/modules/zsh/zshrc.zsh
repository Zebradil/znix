# vim: set filetype=zsh shiftwidth=2 softtabstop=2 expandtab:

tabs -4

for f in "${ZDOTDIR:-}/zshrc/lib/"*.zsh; do
    source "$f"
done

source "${ZDOTDIR:-}/zshrc/paths.zsh"

# +=========================+
# | Shell configuration     |
# +-------------------------+

setopt autocd extendedglob
bindkey -v

autoload -U edit-command-line
zle -N edit-command-line

bindkey -M vicmd v edit-command-line

# The following lines were added by compinstall
zstyle ':completion:*' completer _complete _ignored _approximate
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Za-z}' 'l:|=* r:|=*' 'r:|[._-]=* r:|=*'
#zstyle ':completion:*' max-errors 3

autoload -Uz compinit
compinit
# End of lines added by compinstall

export LC_ALL=en_US.UTF-8
export LC_TIME=en_DK.UTF-8
export LANG=en_US.UTF-8
export NVIM_PROFILE_NAME=astro4
export EDITOR=nv
export LESS='--mouse --wheel-lines=3 --quit-if-one-screen --ignore-case --tabs=4'
export MANPAGER='nv +Man!'

export BAT_THEME=OneHalfDark

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
foreach f ("${ZDOTDIR:-}/zshrc/tools/"*.zsh(N.,@)) { source "$f" }

bindkey -M viins '^[[A' history-beginning-search-backward
bindkey -M vicmd '^[[A' history-beginning-search-backward
bindkey -M viins '^[[B' history-beginning-search-forward
bindkey -M vicmd '^[[B' history-beginning-search-forward
bindkey -M viins '^F' fzf-history-widget
bindkey -M vicmd '^F' fzf-history-widget

source "${ZDOTDIR:-}/zshrc/aliases-and-functions.zsh"

# +=========================+
# | Local overrides         |
# +-------------------------+

[[ -r "$HOME/.zshrc.local" ]] && source $HOME/.zshrc.local
