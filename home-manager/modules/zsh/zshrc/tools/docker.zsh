# +==========================+
# | Docker configuration     |
# +--------------------------+

# Deliberately checking only docker command
if lib::check_commands docker; then
  log::debug "Configuring Docker"

  # Use Docker buildkit by default
  export DOCKER_BUILDKIT=1
  export COMPOSE_DOCKER_CLI_BUILD=1
fi
