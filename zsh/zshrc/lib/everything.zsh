# Shell color codes reference
# https://misc.flogisoft.com/bash/tip_colors_and_formatting

LOGGER_COLOR_DEBUG="\e[1;94m"
LOGGER_COLOR_INFO="\e[1;92m"
LOGGER_COLOR_WARN="\e[1;93m"
LOGGER_COLOR_ERROR="\e[1;91m"
LOGGER_COLOR_RESET="\e[0m"
LOGGER_COLOR_SUCCESS="\e[1;42m"
LOGGER_COLOR_FAILURE="\e[1;41m"
LOGGER_COLOR_HIGHLIGHT="\e[1;37m"

declare -A LOGGER_LOG_LEVELS
LOGGER_LOG_LEVELS=([debug]=1 [info]=2 [warn]=3 [error]=4 [all]=99)
LOGGER_LOG_LEVEL="${LOGGER_LOG_LEVEL:-info}"

# Checks if the given log level is enabled
# Arguments:
#   1. [required] log level (see LOGGER_LOG_LEVELS)
# Returns:
#   0 if the given log level is enabled, 1 otherwise
# Outputs:
#   None
log::_is_level() {
  local level="${1:?}"
  level="${level:l}"
  [[ -z "${LOGGER_LOG_LEVELS[$level]}" ]] && return 1
  ((${LOGGER_LOG_LEVELS[${LOGGER_LOG_LEVEL:l}]} <= ${LOGGER_LOG_LEVELS[$level]}))
}

# Wraps the given string in the given escape sequence
# Arguments:
#   1. [required] escape sequence (e.g. $LOGGER_COLOR_INFO)
#   2. [required] string to wrap
# Returns:
#   0
# Outputs:
#   The wrapped string
log::_logger_wrap_escape() {
  echo -ne "${1:?}${2:?}${LOGGER_COLOR_RESET}"
}

log::_logger_color() {
  local level="${1:?}"
  local marker="${2:?}"
  local paint="${3:?}"
  shift 3

  if log::_is_level "$level"; then
    log::_logger_wrap_escape "$paint" "$marker"
    echo -e " $*"
  fi
}

log::highlight() {
  log::_logger_wrap_escape "$LOGGER_COLOR_HIGHLIGHT" "$1" >&2
}

log::success() {
  log::_logger_color all "SUCCESS" "$LOGGER_COLOR_SUCCESS" "$@" >&2
}

log::failure() {
  log::_logger_color all "FAILURE" "$LOGGER_COLOR_FAILURE" "$@" >&2
}

log::debug() {
  log::_logger_color debug DBG "$LOGGER_COLOR_DEBUG" "$@" >&2
}

log::info() {
  log::_logger_color info INF "$LOGGER_COLOR_INFO" "$@" >&2
}

log::warn() {
  log::_logger_color warn WRN "$LOGGER_COLOR_WARN" "$@" >&2
}

log::error() {
  log::_logger_color error ERR "$LOGGER_COLOR_ERROR" "$@" >&2
}

log::_test() (
  LOGGER_LOG_LEVEL=debug
  log::debug "This is a debug message"
  log::info "This is an info message"
  log::warn "This is a warning message"
  log::error "This is an error message"
  log::success "This is a success message"
  log::failure "This is a failure message"
  log::highlight "This is a highlight message"
)

lib::check_commands() {
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      log::info "Command '$cmd' not found."
      return 1
    fi
  done
}
