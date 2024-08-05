# +==========================+
# | Golang configuration     |
# +--------------------------+

if lib::check_commands go; then
  log::debug "Configuring Golang"
  export GOPATH="${WORKSPACE:?}/go"
fi
