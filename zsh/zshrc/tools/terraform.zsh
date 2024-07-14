# +==========================+
# | Terraform configuration  |
# +--------------------------+

if lib::check_commands terraform; then
  alias tf="terraform"
fi
