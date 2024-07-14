# +==========================+
# | Zoxide directory manager |
# +--------------------------+

if lib::check_commands zoxide; then
  eval "$(zoxide init zsh)"
  export _ZO_FZF_OPTS='+s --preview "exa -l --group-directories-first -T -L5 --color=always --color-scale {2..} | head -200"'
fi
