# +==========================+
# | Vendir configuration     |
# +--------------------------+

if lib::check_commands vendir; then
  log::debug "Configuring vendir"
  export VENDIR_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/vendir"
  mkdir -p "$VENDIR_CACHE_DIR"
  export VENDIR_MAX_CACHE_SIZE=1Gi
fi
