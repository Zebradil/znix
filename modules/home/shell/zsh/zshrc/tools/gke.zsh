# Functions for managing GKE clusters and node pools
# Assumed to be used with kubeconfigs populated by gke-kubeconfiger with --add-metadata flag:
#   https://github.com/Zebradil/gke-kubeconfiger

# Outputs the current cluster name, project ID and location
function z:gke:cluster:info() (
  set -euo pipefail
  local context cluster_name project_id location kubeconfig="${KUBECONFIG:?}"
  context=$(kubectl config current-context)
  read -r cluster_name project_id location \
    < <(context=$context yq eval-all '
        (.contexts[] | select(.name == strenv(context)) | .context.cluster) as $cluster
        | .clusters[]
        | select(.name == $cluster)
        | .cluster.gkeMetadata
        | select(.clusterName or .projectID or .location)
        | "\(.clusterName) \(.projectID) \(.location)"' \
      ${(s.:.)kubeconfig})
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

# List all node pools in the current GKE cluster with node and pod counts
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

  typeset -A node_count pod_count node_pool
  local pool node
  while IFS=$'\t' read -r pool node; do
    [[ -z $pool || -z $node ]] && continue
    node_pool[$node]=$pool
    (( node_count[$pool]++ )) || true
  done < <(kubectl get nodes \
    -o jsonpath='{range .items[*]}{.metadata.labels.cloud\.google\.com/gke-nodepool}{"\t"}{.metadata.name}{"\n"}{end}')

  while read -r node; do
    [[ -z $node ]] && continue
    pool=${node_pool[$node]:-}
    [[ -n $pool ]] && (( pod_count[$pool]++ )) || true
  done < <(kubectl get pods --all-namespaces \
    --field-selector=status.phase=Running \
    -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}')

  {
    print "NAME\tMACHINE_TYPE\tSPOT\tAUTOSCALING\tPPN\tNODES\tPODS"
    gcloud container node-pools list \
      --cluster "$cluster_name" \
      --project "$project_id" \
      --location "$location" \
      --format='value[separator="	"](name,config.machineType,config.spot.yesno(yes=True,no=False),autoscaling.enabled.yesno(yes=True,no=False),maxPodsConstraint.maxPodsPerNode)' \
    | while IFS=$'\t' read -r name mtype spot as ppn; do
        print "$name\t$mtype\t$spot\t$as\t${ppn:-?}\t${node_count[$name]:-0}\t${pod_count[$name]:-0}"
      done | sort
  } | column -ts $'\t'
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
# Usage: z:gke:np:select [--multi]
# Args:
#   --multi  allow selecting multiple node pools (one name per output line)
function z:gke:np:select() (
  set -euo pipefail
  local multi=false
  [[ ${1:-} == "--multi" ]] && multi=true
  local list selected
  list=$(z:gke:np:list)
  if [[ -z $list ]]; then
    return 1
  fi
  local -a fzf_args=(--header-lines=1)
  $multi && fzf_args+=(--multi)
  selected=$(echo "$list" | fzf "${fzf_args[@]}" | awk '{print $1}')
  if [[ -z $selected ]]; then
    log::error "No node pool selected"
    return 1
  fi
  echo "$selected"
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

# Drain and delete one or more node pools:
#  - Select node pools interactively if '-' is given
#  - Pools with 0 nodes are deleted directly (no drain steps)
#  - For non-empty pools: optionally taint, disable autoscaling/autorepair,
#    drain all nodes, then delete the pool
#  - Pools are processed one by one in order
# Usage: z:gke:np:drain-delete <node-pool|->... [--taint-pool] [drain-nodes-args...]
# Args:
#   <node-pool|->...       one or more pool names; '-' opens a multi-select fzf picker
#   --taint-pool           apply zebradil.dev/draining=true:NoSchedule to the pool
#                          so any nodes GKE spawns during drain are unschedulable
#   [drain-nodes-args...]  additional arguments to pass to drain-nodes
function z:gke:np:drain-delete() (
  set -euo pipefail

  local -a pools=()
  while (( $# > 0 )) && [[ $1 != --* ]]; do
    pools+=("$1")
    shift
  done
  if (( ${#pools[@]} == 0 )); then
    log::error "node pool missing"
    return 1
  fi

  local -a resolved=()
  local p picked_lines
  for p in "${pools[@]}"; do
    if [[ $p == "-" ]]; then
      picked_lines=("${(@f)$(z:gke:np:select --multi)}")
      (( ${#picked_lines[@]} == 0 )) && return 1
      resolved+=("${picked_lines[@]}")
    else
      resolved+=("$p")
    fi
  done
  (( ${#resolved[@]} == 0 )) && return 1

  local taint_pool=false
  local -a drain_args=()
  while (( $# > 0 )); do
    case "$1" in
      --taint-pool) taint_pool=true ;;
      *)            drain_args+=("$1") ;;
    esac
    shift
  done

  local total=${#resolved[@]}
  local idx=0
  local np
  for np in "${resolved[@]}"; do
    (( idx++ ))
    log::info "===== Processing node pool $np ($idx/$total) ====="

    local -a nodes=("${(@f)$(z:gke:np:nodes $np)}")
    (( ${#nodes[@]} == 1 )) && [[ -z ${nodes[1]} ]] && nodes=()

    if (( ${#nodes[@]} == 0 )); then
      log::info "Node pool $np has 0 nodes — deleting directly"
      z:gke:np:do delete $np
      continue
    fi

    if $taint_pool; then
      # Appends the draining taint to whatever the pool already has.
      log::info "Appending taint zebradil.dev/draining=true:NoSchedule to node pool $np ..."
      local merged_taints
      merged_taints=$(
        z:gke:np:do describe $np --format=json \
          | jq -r '
              (.config.taints // [])
              | map(select(.key != "zebradil.dev/draining"))
              | map("\(.key)=\(.value):" + (
                  {NO_SCHEDULE:"NoSchedule",
                   PREFER_NO_SCHEDULE:"PreferNoSchedule",
                   NO_EXECUTE:"NoExecute"}[.effect] // .effect))
              + ["zebradil.dev/draining=true:NoSchedule"]
              | join(",")
            '
      )
      z:gke:np:do update $np --node-taints="$merged_taints" --quiet
    fi

    log::info "Disabling autoscaling and autorepair on node pool $np ..."
    # Workaround for fantom autoscaling noticed in GKE v1.35: before disabling autoscaling set max nodes to 0
    z:gke:np:do update $np --total-min-nodes=0 --total-max-nodes=0
    z:gke:np:do update $np --no-enable-autoscaling
    z:gke:np:do update $np --no-enable-autorepair

    log::info "Draining and deleting ${#nodes[@]} node(s) in node pool $np ..."
    printf '%s\n' "${nodes[@]}" | drain-nodes --delete "${drain_args[@]}"

    log::info "Deleting node pool $np ..."
    z:gke:np:do delete $np
  done
)

