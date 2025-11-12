# +==========================+
# | Tailscale                |
# +--------------------------+

if lib::check_commands tailscale; then
  log::debug "Configuring tailscale aliases and functions"
  function z:tailscale:switch() {
    local tailnet="$1"
    log::info "Switching to tailscale networks requires sudo"
    sudo --validate
    if [[ -z $tailnet ]]; then
      tailnet=$(sudo tailscale switch --list | tail -n +2 | fzf | awk '{print $1}')
      if [[ -z $tailnet ]]; then
        log::error "No network selected"
        return 1
      fi
    fi
    sudo tailscale switch "$tailnet"
  }
  alias tssw=z:tailscale:switch

  # Re-generates kubeconfigs for all Kubernetes clusters available via Tailscale
  function z:tailscale:kubeconfig:init() (
    local configs_dir=~/.kube/tailscale.clusters
    local clusters
    clusters=$(tailscale status | rg '\bts-op-([^\s]+)' --replace='tailscale-$1' --only-matching)
    if [[ -z $clusters ]]; then
      log::warn "No Tailscale Kubernetes clusters found"
      return 0
    fi
    rm -rf "$configs_dir"
    mkdir -p "$configs_dir"
    log::info "Generating kubeconfig for Tailscale clusters:"
    while read -r cluster_name; do
      if [[ -z $cluster_name ]]; then
        continue
      fi
      export KUBECONFIG="$configs_dir/$cluster_name.yaml"
      log::info "  - $cluster_name"
      tailscale configure kubeconfig "$cluster_name"
    done <<<"$clusters"
  )
fi
