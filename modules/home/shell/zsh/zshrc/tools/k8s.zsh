# +==========================+
# | Kubernetes configuration |
# +--------------------------+

if lib::check_commands krew; then
  export KREW_ROOT="${XDG_DATA_HOME:?}/krew"
  path+=("${KREW_ROOT:?}/bin")
fi

function z:k8s:kubeconfig:list-files() {
  echo ~/.kube/*clusters/*.y?ml(N)
}

function z:k8s:kubeconfig:init() {
  export KUBECONFIG="${(j.:.)${(s: :)$(z:k8s:kubeconfig:list-files)}}"
}

# Generate a kubeconfig file that overrides the current context to the specified one.
# If no context is specified, prompt the user to select one via fzf.
# Returns the new KUBECONFIG value that includes the override file.
# If the specified context is already the current context, returns exit code 100 and no output.
function z:k8s:context:generate-kubeconfig() (
  set -euo pipefail
  local ctx=${1:-}
  local prefix="zctx_"
  local context_override_dir="${XDG_STATE_HOME:?}/k8s/contexts"
  local kubeconfig_items=(${(s.:.)KUBECONFIG})
  if [[ -z $ctx ]]; then
    kubectl config get-contexts \
      | fzf --header-lines=1 \
      | awk '{print $1}' \
      | read -r ctx _
  fi
  if [[ -z $ctx ]]; then
    log::error "No context selected"
    return 101
  fi
  # "*" means that the desired context is already selected
  if [[ $ctx == "*" ]]; then
    return 100
  fi
  if ! kubectl config get-contexts "$ctx" &>/dev/null; then
    log::error "Context '$ctx' does not exist"
    return 1
  fi
  mkdir -p "$context_override_dir"
  local ctx_override_file="$context_override_dir/$prefix$ctx.yaml"
  if [[ ! -f $ctx_override_file ]]; then
    echo "current-context: \"$ctx\"" >"$ctx_override_file"
  fi
  echo "$ctx_override_file:${(j.:.)${(@)kubeconfig_items:#$context_override_dir/*}}"
)

function z:k8s:context:switch() {
  local context="$1"
  local new_kubeconfig
  new_kubeconfig="$(z:k8s:context:generate-kubeconfig "$context")"
  ret=$?
  case $ret in
    101) log::info "Aborted" ; return 1 ;;
    100) log::info "Already on context '$context'" ; return 0 ;;
    0) export KUBECONFIG="$new_kubeconfig" ;;
    *) log::error "Failed to switch context to '$context'"; return $ret ;;
  esac
}

function z:k8s:context:switch-k9s() {
  z:k8s:context:switch $1 && k9s
}

function z:k8s:contexts:do-parallel() {
  if (( $# < 2 )); then
    log::error "Too few arguments"
    log::info "Usage: ${funcstack[1]} <file suffix> <command> [args...]"
    return 1
  fi
  z:k8s:contexts:do-parallel-filter ".*" "$1" "${@:2}"
}


function z:k8s:contexts:do-parallel-filter() {
  if (( $# < 3 )); then
    log::error "Too few arguments"
    log::info "Usage: ${funcstack[1]} <rg pattern> <file suffix> <command> [args...]"
    return 1
  fi
  local rg_pattern=$1
  local suffix=$2
  shift 2
  local -a cmd_args=("$@")

  local -a contexts
  contexts=(${(f)"$(kubectl config get-contexts -oname | rg "$rg_pattern")"})

  if (( ${#contexts} == 0 )); then
    log::warn "No contexts found"
    return 0
  fi

  _z_k8s_parallel_job() {
    local ctx=$1
    z:k8s:context:switch "$ctx"
    eval "${cmd_args[@]}" >"${ctx}${suffix}"
  }

  lib::parallel::run -c _z_k8s_parallel_job -- "${contexts[@]}"
}


function z:k8s:namespaces:dump() {
  if (( $# < 2 )); then
    log::error "Too few arguments"
    log::info "Usage: ${funcstack[1]} <rg pattern> <out dir>"
    return 1
  fi
  local rg_pattern=$1
  local out_dir=$2

  local -a namespaces
  namespaces=(${(f)"$(
    kubectl get namespaces -o custom-columns=NAME:.metadata.name --no-headers \
      | rg "$rg_pattern"
  )"})
  if (( ${#namespaces} == 0 )); then
    log::warn "No namespaces matched pattern '$rg_pattern'"
    return 0
  fi

  local -a kinds
  kinds=(${(f)"$(kubectl api-resources --verbs=list --namespaced -o name)"})
  if (( ${#kinds} == 0 )); then
    log::error "No namespaced api-resources found"
    return 1
  fi

  mkdir -p "$out_dir"
  local progress_dir
  progress_dir=$(mktemp -d)

  _z_k8s_ns_dump_job() {
    local ns=$1
    local ns_dir="$out_dir/$ns"
    mkdir -p "$ns_dir" "$progress_dir/$ns"
    local kind
    for kind in "${kinds[@]}"; do
      (
        kubectl get --ignore-not-found -n "$ns" "$kind" -oyaml \
          > "$ns_dir/$kind.yaml"
        : > "$progress_dir/$ns/$kind"
      ) &
    done
    wait
    find "$ns_dir" -size 0 -delete
  }

  _z_k8s_ns_dump_status() {
    local ns=$2
    local -a done_files=("$progress_dir/$ns"/*(N))
    local count=${#done_files}
    local total=${#kinds}
    local width=20
    local filled=$(( count * width / total ))
    local bar="" i
    for (( i = 0; i < width; i++ )); do
      (( i < filled )) && bar+="█" || bar+="░"
    done
    printf 'running [%s] %d/%d' "$bar" "$count" "$total"
  }

  lib::parallel::run \
    -c _z_k8s_ns_dump_job \
    -s _z_k8s_ns_dump_status \
    -- "${namespaces[@]}"
  local rc=$?
  rm -rf "$progress_dir"
  return $rc
}

z:k8s:kubeconfig:init

if lib::check_commands kubectl; then
  source <(kubectl completion zsh | sed '/"-f"/d')
fi

alias k="kubectl"
alias kd="kubectl describe"
alias kgy="kubectl get -oyaml"
alias kga="kubectl get -A"

alias kc=z:k8s:context:switch
alias kk=z:k8s:context:switch-k9s

function _z:k8s:contexts:list() {
  local contexts
  contexts=($(kubectl config get-contexts -o name | sort -u))
  if [[ -n $contexts ]]; then
    _describe -t contexts "Kubernetes contexts" contexts
  else
    _message "No Kubernetes contexts found"
  fi
}

compdef _z:k8s:contexts:list z:k8s:context:switch z:k8s:context:switch-k9s
