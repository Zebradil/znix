# +==========================+
# | Orca                     |
# +--------------------------+

# Orca's shell wrapper defines a `claude` function after zshrc whenever this
# pointer is set, to route claude through Orca's account picker. The znix
# wrappers already own the config dir per command (claude = personal,
# trv-claude = company) and override whatever the function sets, so drop the
# pointer and keep `claude` resolving to the wrapper, as in any other terminal.
unset ORCA_CLAUDE_PROFILE_POINTER
