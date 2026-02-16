# +==========================+
# | Terraform                |
# +--------------------------+

if lib::check_commands terraform; then
  export TF_PLUGIN_CACHE_DIR="$XDG_CACHE_HOME/terraform/plugin-cache"
  mkdir -p "$TF_PLUGIN_CACHE_DIR"
fi
