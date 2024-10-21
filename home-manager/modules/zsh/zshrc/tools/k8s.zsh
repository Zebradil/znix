# +==========================+
# | Kubernetes configuration |
# +--------------------------+

if lib::check_commands kubectl; then
  alias k="kubectl"
  alias kd="kubectl describe"
  alias kgy="kubectl get -oyaml"
  alias kga="kubectl get -A"

  source <(kubectl completion zsh | sed '/"-f"/d')
fi

function z:k8s:kubeconfig:list-files() {
  echo ~/.kube/*clusters/*.y?ml(N)
}

function z:k8s:kubeconfig:init() {
  export KUBECONFIG="${(j.:.)${(s: :)$(z:k8s:kubeconfig:list-files)}}"
}

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
  if [[ $ctx == "*" ]]; then
    return 0
  fi
  mkdir -p "$context_override_dir"
  local ctx_override_file="$context_override_dir/$prefix$ctx.yaml"
  if [[ ! -f $ctx_override_file ]]; then
    echo "current-context: \"$ctx\"" >"$ctx_override_file"
  fi
  echo "$ctx_override_file:${(j.:.)${(@)kubeconfig_items:#$context_override_dir/*}}"
)

function z:k8s:context:switch() {
  new_kubeconfig=$(z:k8s:context:generate-kubeconfig $1)
  if [[ $? -ne 0 ]]; then
    return 1
  fi
  if [[ -z $new_kubeconfig ]]; then
    return 1
  fi
  export KUBECONFIG="$new_kubeconfig"
}

function z:k8s:contexts:do-parralel() {
  if (( $# < 2 )); then
    log::error "Too few arguments"
    log::info "Usage: z:k8s:contexts:do-parralel <suffix> <command> [args...]"
    return 1
  fi
  local suffix=$1
  shift
  local worked=0
  for ctx in $(kubectl config get-contexts -oname); do
    worked=1
    (
      set -euo pipefail
      z:k8s:context:switch $ctx
      eval "$@" >"${ctx}${suffix}"
    ) &
  done
  if (( worked == 0 )); then
    log::warn "No contexts found"
  fi
}

alias kc=z:k8s:context:switch
alias kk='kc && k9s'

# DEPRECATED
alias s=kc
