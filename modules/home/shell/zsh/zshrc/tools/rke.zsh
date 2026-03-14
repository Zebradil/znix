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
  local -a cmd_args=("$@")

  local -a items=()
  local node ip _rest
  while read -r node ip _rest; do
    if rg -q "$rg_pattern" <<<"$node"; then
      items+=("${node}::${ip}")
    fi
  done < <(z:rke2:node:list)

  if (( ${#items} == 0 )); then
    log::warn "No nodes found"
    return 0
  fi

  _z_rke2_parallel_job() {
    local item=$1
    local node=${item%%::*}
    local ip=${item#*::}
    ssh "$ip" "${cmd_args[@]}" >"${node}${suffix}"
  }

  lib::parallel::run -c _z_rke2_parallel_job -- "${items[@]}"
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
    | yq -r '
  .items[].metadata
  | [
    .name,
    .annotations
      | .["rke2.io/internal-ip"] // .["k3s.io/internal-ip"]
      | split(",")[0],
    [
      .labels
      | to_entries[]
      | select(.key == "node-role.kubernetes.io/*").key
      | split("/")[1]
    ] | join(",")
  ] | @tsv'
}

function z:rke2:node:select() {
  local node ip
  {
    echo "NAME IP ROLES"
    z:rke2:node:list
  } \
    | column -t \
    | fzf --header-lines=1 --no-multi \
    | awk '{print $1}'
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
