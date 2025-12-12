# +==========================+
# | RKE2 library             |
# +--------------------------+

function z:rke2:nodes:do-parallel-filter() {
  if (($# < 3)); then
    log::error "Too few arguments"
    log::info "Usage: ${funcstack[1]} <rg pattern> <file suffix> <command> [args...]"
    return 1
  fi
  local rg_pattern=$1
  local suffix=$2
  shift 2
  local worked=0
  while read -r node ip; do
    if rg -q "$rg_pattern" <<<"$node"; then
      worked=1
      (
        set -euo pipefail
        eval "$@" >"${node}${suffix}"
      ) &
    fi
  done < <(kubectl get nodes -o yaml \
    | yq '.items[] | .metadata | [.name, .annotations["rke2.io/internal-ip"] | split(",")[0]] | @tsv')
  if ((worked == 0)); then
    log::warn "No nodes found"
  else
    wait
  fi
}

function z:rke2:nodes:do-parallel() {
  if (($# < 2)); then
    log::error "Too few arguments"
    log::info "Usage: ${funcstack[1]} <file suffix> <command> [args...]"
    return 1
  fi
  z:rke2:nodes:do-parallel-filter ".*" "$1" "${@:2}"
}
