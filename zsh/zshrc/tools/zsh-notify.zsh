# +==========================+
# | zsh-notify configuration |
# +--------------------------+

zstyle ':notify:*' error-title "💔 Command failed in #{time_elapsed}"
zstyle ':notify:*' success-title "🏁 Command finished in #{time_elapsed}"
zstyle ':notify:*' command-complete-timeout 5
zstyle ':notify:*' expire-time 3000
