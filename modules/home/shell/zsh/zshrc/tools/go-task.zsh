# +==========================+
# | Go-task configuration    |
# +--------------------------+

if lib::check_commands go-task; then
  log::debug "Configuring go-task"

  export GOTASK_BIN=go-task
  alias gt=go-task
fi
