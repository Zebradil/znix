# +==========================+
# | Antidote plugin manager  |
# +--------------------------+

antidote_plugins="$(
  <<EOF
hcgraf/zsh-sudo
jeffreytse/zsh-vi-mode
marzocchi/zsh-notify
robbyrussell/oh-my-zsh path:lib/git.zsh
robbyrussell/oh-my-zsh path:plugins/docker-machine
robbyrussell/oh-my-zsh path:plugins/git
unixorn/git-extra-commands
zchee/zsh-completions
zdharma-continuum/history-search-multi-word
zsh-users/zsh-autosuggestions
zsh-users/zsh-history-substring-search
zsh-users/zsh-syntax-highlighting
djui/alias-tips
EOF
)"

antidote_source=/usr/share/zsh-antidote/antidote.zsh

if [[ ! -f $antidote_source ]]; then
  log::info "Antidote plugin manager not found. Please install it."
else
  # This branch is executed every time the shell is started.
  # That's why debug level is used.
  log::debug "Configuring Antidote"

  source "$antidote_source"

  plugins_txt=${ZDOTDIR:-~}/.zsh_plugins.txt
  static_file=${ZDOTDIR:-~}/.zsh_plugins.zsh

  if [[ ! $static_file -nt $plugins_txt ]]; then
    log::debug "Installing antidote plugins..."
    antidote bundle <<<"$antidote_plugins" >"$static_file"
  fi

  log::debug "Sourcing antidote plugins from $static_file"
  # ZSH-VI-MODE: Do the initialization when the script is sourced (i.e. Initialize instantly)
  ZVM_INIT_MODE=sourcing
  source "$static_file"

  unset plugins_txt static_file

  # ZSH-NOTIFY
  {
    if ! lib::check_commands notify-send xdotool wmctrl; then
      log::warn "notify-send, xdotool and wmctrl are required for marzocchi/zsh-notify to work."
    fi

    zstyle ':notify:*' error-title "💔 Command failed in #{time_elapsed}"
    zstyle ':notify:*' success-title "🏁 Command finished in #{time_elapsed}"
    zstyle ':notify:*' command-complete-timeout 5
    zstyle ':notify:*' expire-time 3000
  }

fi

unset antidote_plugins antidote_source
