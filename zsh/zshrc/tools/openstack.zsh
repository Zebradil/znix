# +==========================+
# | Openstack configuration  |
# +--------------------------+

if lib::check_commands openstack; then
  alias os="openstack"
fi
