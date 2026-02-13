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
      echo "> '$node' (${ip:?missing IP})"
      worked=1
      (
        set -euo pipefail
        ssh "$ip" "$@" >"${node}${suffix}"
      ) &
    fi
  done < <(z:rke2:node:list)
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

function z:rke2:node:list() {
  kubectl get nodes -o yaml \
    | yq -r '.items[]
            | .metadata
            | [
              .name,
              (.annotations | .["rke2.io/internal-ip"] // .["k3s.io/internal-ip"])
                | split(",")[0]
            ]
            | @tsv'
}

function z:rke2:node:select() {
  local node ip
  while read -r node ip; do
    echo "$node (${ip:-unknown})"
  done < <(z:rke2:node:list) | fzf --header-lines=1 | awk '{print $1}'
}

function z:rke2:node:ssh() {
  local node=${1:?node name missing}
  local ip
  if [[ $node == "-" ]]; then
    node=$(z:rke2:node:select)
  fi
  if [[ -z $node ]]; then
    return 1
  fi
  ip=$(z:rke2:node:list | rg "^${node}\s" | awk '{print $2}')
  if [[ -z $ip ]]; then
    log::error "Node '$node' not found"
    return 1
  fi
  ssh "$ip"
}
