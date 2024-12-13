# Re-generates kubeconfigs for all Rancher clusters
function z:rancher:kubeconfig:init() {
  local configs_dir=~/.kube/rancher.clusters
  rm -rf "$configs_dir"
  mkdir -p "$configs_dir"
  log::info "Generating kubeconfig for Rancher clusters:"
  while read -r cluster_name cluster_id; do
    local kubeconfig_file="$configs_dir/$cluster_name.yaml"
    log::info "  - $cluster_name ($cluster_id)"
    rancher cluster kubeconfig "$cluster_id" \
      | yq 'del(.current-context) | .contexts[0].name |= "rancher-" + .' >"$kubeconfig_file"
  done < <(rancher cluster ls --format 'rancher-{{.Name}} {{.ID}}')
}

