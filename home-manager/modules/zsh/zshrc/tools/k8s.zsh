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
  local worked=0
  for ctx in $(kubectl config get-contexts -oname | rg "$rg_pattern"); do
    worked=1
    (
      set -euo pipefail
      z:k8s:context:switch $ctx
      eval "$@" >"${ctx}${suffix}"
    ) &
  done
  if (( worked == 0 )); then
    log::warn "No contexts found"
  else
    wait
  fi
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
