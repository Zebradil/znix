# Functions for managing GKE clusters and node pools
# Assumed to be used with kubeconfigs populated by gke-kubeconfiger with --add-metadata flag:
#   https://github.com/Zebradil/gke-kubeconfiger

# Outputs the current cluster name, project ID and location
function z:gke:cluster:info() (
  set -euo pipefail
  local cluster_name project_id location kubeconfig="${KUBECONFIG:?}"
  read -r cluster_name project_id location \
      < <(yq -r '.gkeMetadata | "\(.clusterName) \(.projectID) \(.location)"' "$kubeconfig")
  if [[ -z $cluster_name ]]; then
    log::error "Could not determine the current GKE cluster"
    return 1
  fi
  if [[ -z $project_id ]]; then
    log::error "Could not determine the current GCP project ID"
    return 1
  fi
  if [[ -z $location ]]; then
    log::error "Could not determine the current GCP location"
    return 1
  fi
  log::debug "Cluster: $cluster_name, Project ID: $project_id, location: $location"
  echo "$cluster_name $project_id $location"
)

# Run a gcloud command on the current GKE cluster
# Usage: z:gke:cluster:do <command> [args...]
# Args:
#   <command>  gcloud container clusters command to run on the cluster
#   [args...]  additional arguments to pass to the command
function z:gke:cluster:do() (
  set -euo pipefail
  local cmd=${1:?command missing}
  shift
  local cluster_name project_id location info
  info=$(z:gke:cluster:info)
  if [[ -z $info ]]; then
    return 1
  fi
  read -r cluster_name project_id location <<< "$info"
  log::info "Running command: $cmd on cluster $cluster_name ..."
  gcloud container clusters "${cmd}" "$cluster_name" \
    --project "$project_id" \
    --location "$location" \
    "$@"
)

# List all node pools in the current GKE cluster
# Usage: z:gke:np:list
function z:gke:np:list() (
  set -euo pipefail
  local cluster_name project_id location info
  info=$(z:gke:cluster:info)
  if [[ -z $info ]]; then
    return 1
  fi
  read -r cluster_name project_id location <<< "$info"
  log::info "Listing node pools for cluster $cluster_name ..."
  gcloud container node-pools list \
    --cluster "$cluster_name" \
    --project "$project_id" \
    --location "$location" \
    --format="table(
      name,
      config.machineType,
      config.spot,
      autoscaling.enabled
    )"
)

# Run node pool command: create, delete, update, etc.
# Usage: z:gke:np:do <command> <node-pool|-> [args...]
# Args:
#   <command>      'gcloud container node-pools' command to run on the node pool
#                  (complete-upgrade, create, delete, describe, rollback, update)
#   <node-pool|->  node pool name or '-' to select interactively
#   [args...]      additional arguments to pass to the command
function z:gke:np:do() (
  set -euo pipefail
  local cluster_name project_id location info
  local cmd=${1:?command missing}
  local np=${2:?node pool missing}
  shift 2
  info=$(z:gke:cluster:info)
  if [[ -z $info ]]; then
    return 1
  fi
  if [[ $np == "-" ]]; then
    np=$(z:gke:np:select)
  fi
  if [[ -z $np ]]; then
    return 1
  fi
  read -r cluster_name project_id location <<< "$info"
  log::info "Running command: $cmd on node pool $np ..."
  gcloud container node-pools "${cmd}" "${np}" \
    --cluster "$cluster_name" \
    --project "$project_id" \
    --location "$location" \
      "$@"
)

# Interactively select a node pool to operate on
# Usage: z:gke:np:select
function z:gke:np:select() (
  set -euo pipefail
  local np list
  list=$(z:gke:np:list)
  if [[ -z $list ]]; then
    return 1
  fi
  np=$(echo "$list" | fzf --header-lines=1 | awk '{print $1}')
  if [[ -z $np ]]; then
    log::error "No node pool selected"
    return 1
  fi
  echo "$np"
)

# Print all nodes in a node pool
# Usage: z:gke:np:nodes <node-pool|->
# Args:
#   <node-pool|->  node pool name or '-' to select interactively
function z:gke:np:nodes() (
  set -euo pipefail
  local np=${1:?node pool missing}
  if [[ $np == "-" ]]; then
    np=$(z:gke:np:select)
  fi
  if [[ -z $np ]]; then
    return 1
  fi
  log::info "Listing nodes in node pool $np ..."
  kubectl get node \
    -o custom-columns=:.metadata.name \
    --no-headers \
    -l=cloud.google.com/gke-nodepool="$np"
)

# Print all nodes in a node pool with more than a minimum number of pods
# Useful for identifying nodes that have only pods of daemonsets
# TODO: Implement proper detection of daemonset pods
function z:gke:np:nodes:with-pods() (
  set -euo pipefail
  local np=${1:?node pool missing}
  local min_pods=${2:-1}
  for node in $(z:gke:np:nodes $np); do
    log::info "Listing pods on node $node ..."
    pod_count=$(kubectl get pods \
      --all-namespaces \
      --field-selector spec.nodeName=$node \
      --output=name \
      --no-headers \
      | wc -l)
    if (( $pod_count > $min_pods - 1 )); then
      echo $node
    fi
  done
)

# Drain and delete a node pool:
#  - Select a node pool interactively if not provided
#  - Disable autoscaling
#  - Drain all nodes in the node pool and delete them
#  - Delete the node pool
# Usage: z:gke:np:drain-delete <node-pool|-> [drain-nodes-args...]
# Args:
#   <node-pool|->          node pool name or '-' to select interactively
#   [drain-nodes-args...]  additional arguments to pass to drain-nodes
function z:gke:np:drain-delete() (
  set -euo pipefail
  local np=${1:?node pool missing}
  shift
  if [[ $np == "-" ]]; then
    np=$(z:gke:np:select)
  fi
  if [[ -z $np ]]; then
    return 1
  fi
  log::info "Disabling autoscaling and autorepair on node pool $np ..."
  z:gke:np:do update $np --no-enable-autoscaling
  z:gke:np:do update $np --no-enable-autorepair
  log::info "Draining and deleting nodes in node pool $np ..."
  z:gke:np:nodes $np | drain-nodes --delete $@
  log::info "Deleting node pool $np ..."
  z:gke:np:do delete $np
)

