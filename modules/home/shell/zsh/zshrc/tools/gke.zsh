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
  read -r cluster_name project_id location <<<"$info"
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
  read -r cluster_name project_id location <<<"$info"
  log::info "Listing node pools for cluster $cluster_name ..."

  typeset -A node_count pod_count node_pool
  local pool node
  while IFS=$'\t' read -r pool node; do
    [[ -z $pool || -z $node ]] && continue
    node_pool[$node]=$pool
    ((node_count[$pool]++)) || true
  done < <(kubectl get nodes \
    -o jsonpath='{range .items[*]}{.metadata.labels.cloud\.google\.com/gke-nodepool}{"\t"}{.metadata.name}{"\n"}{end}')

  while read -r node; do
    [[ -z $node ]] && continue
    pool=${node_pool[$node]:-}
    [[ -n $pool ]] && ((pod_count[$pool]++)) || true
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
  read -r cluster_name project_id location <<<"$info"
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

# List all pods running on the nodes of a node pool
# Usage: z:gke:np:nodes:pods <node-pool|->
# Args:
#   <node-pool|->  node pool name or '-' to select interactively
function z:gke:np:nodes:pods() (
  set -euo pipefail
  local np=${1:?node pool missing}
  if [[ $np == "-" ]]; then
    np=$(z:gke:np:select)
  fi
  if [[ -z $np ]]; then
    return 1
  fi
  log::info "Listing pods on nodes of pool $np ..."
  {
    printf 'NODE\tNAMESPACE\tNAME\n'
    local node
    for node in $(z:gke:np:nodes $np); do
      kubectl get pods \
        --all-namespaces \
        --field-selector spec.nodeName=$node \
        -o custom-columns=NODE:.spec.nodeName,NAMESPACE:.metadata.namespace,NAME:.metadata.name \
        --no-headers \
        | awk -v OFS='\t' '{print $1, $2, $3}'
    done
  } | column -ts $'\t'
)

# Print all nodes in a node pool with more than a minimum number of pods
# Useful for identifying nodes that have only pods of daemonsets
# TODO: Implement proper detection of daemonset pods
# Usage: z:gke:np:nodes:with-pods <node-pool|-> [min_pods]
# Args:
#   <node-pool|->  node pool name or '-' to select interactively
#   [min_pods]     minimum pod count threshold (default 1)
function z:gke:np:nodes:with-pods() (
  set -euo pipefail
  local np=${1:?node pool missing}
  local min_pods=${2:-1}
  if [[ $np == "-" ]]; then
    np=$(z:gke:np:select)
  fi
  if [[ -z $np ]]; then
    return 1
  fi
  z:gke:np:nodes:pods $np \
    | tail -n +2 \
    | awk '{print $1}' \
    | sort \
    | uniq -c \
    | awk -v min="$min_pods" '$1 >= min {print $2}'
)

# Drain and delete one or more node pools:
#  - Select node pools interactively if '-' is given
#  - Pools with 0 nodes are deleted directly (no drain steps)
#  - For non-empty pools: optionally taint, disable autoscaling/autorepair,
#    drain all nodes, then delete the pool
#  - Pools are processed one by one in order
# Usage: z:gke:np:drain-delete <node-pool|->... [--taint-pool] [--yes|-y] [--notify[=<channel>[:<thread_ts>]]] [--no-notify] [drain-nodes-args...]
# Args:
#   <node-pool|->...       one or more pool names; '-' opens a multi-select fzf picker
#   --taint-pool           apply zebradil.dev/draining=true:NoSchedule to the pool
#                          so any nodes GKE spawns during drain are unschedulable
#   --yes, -y              suppress gcloud confirmation prompts on update/delete calls
#   [drain-nodes-args...]  additional arguments to pass to drain-nodes
# Notifications (Slack):
#   Configure via env:
#     ZNIX_SLACK_TOKEN_OP_REF  1Password ref to the bot token (required when notifying)
#     ZNIX_SLACK_CHANNEL       channel id, or "<channel>:<thread_ts>" to pin to a thread
#     ZNIX_SLACK_USER_HANDLE   optional mention prefix (e.g. "<@U0123456789>")
#   --notify[=<channel>[:<thread_ts>]]  enable; override channel/thread if given
#   --no-notify                         skip without prompting
#   With neither flag the function prompts once for the whole run; answering
#   "yes" with required env unset aborts with an error.
function z:gke:np:drain-delete() (
  set -euo pipefail

  local -a pools=()
  while (($# > 0)) && [[ $1 != --* ]]; do
    pools+=("$1")
    shift
  done
  if ((${#pools[@]} == 0)); then
    log::error "node pool missing"
    return 1
  fi

  local -a resolved=()
  local p picked_lines
  for p in "${pools[@]}"; do
    if [[ $p == "-" ]]; then
      picked_lines=("${(@f)$(z:gke:np:select --multi)}")
      ((${#picked_lines[@]} == 0)) && return 1
      resolved+=("${picked_lines[@]}")
    else
      resolved+=("$p")
    fi
  done
  ((${#resolved[@]} == 0)) && return 1

  local taint_pool=false
  local notify_flag=""
  # notify_channel may be "<channel>" or "<channel>:<thread_ts>" — z:slack:post
  # and z:slack:update both accept the combined form.
  local notify_channel="${ZNIX_SLACK_CHANNEL:-}"
  local -a drain_args=() gcloud_yes_args=()
  while (($# > 0)); do
    case "$1" in
    --taint-pool) taint_pool=true ;;
    --yes | -y) gcloud_yes_args=(--quiet) ;;
    --no-notify) notify_flag="no" ;;
    --notify) notify_flag="yes" ;;
    --notify=*)
      notify_flag="yes"
      notify_channel="${1#--notify=}"
      ;;
    *) drain_args+=("$1") ;;
    esac
    shift
  done

  local notify=false
  if [[ $notify_flag == "no" ]]; then
    notify=false
  elif [[ $notify_flag == "yes" ]]; then
    notify=true
  else
    if read -q "REPLY?Send Slack notifications? [y/N] "; then
      notify=true
    fi
    print
  fi

  local slack_token=""
  if $notify; then
    if [[ -z ${ZNIX_SLACK_TOKEN_OP_REF:-} ]]; then
      log::error "Slack notifications requested but ZNIX_SLACK_TOKEN_OP_REF is not set"
      return 1
    fi
    if [[ -z $notify_channel ]]; then
      log::error "Slack notifications requested but no channel configured (set ZNIX_SLACK_CHANNEL or use --notify=<channel>)"
      return 1
    fi
    slack_token=$(op read "$ZNIX_SLACK_TOKEN_OP_REF") || {
      log::error "Failed to fetch Slack bot token from 1Password"
      return 1
    }
  fi

  local cluster_name info
  info=$(z:gke:cluster:info)
  if [[ -z $info ]]; then
    return 1
  fi
  read -r cluster_name _ _ <<<"$info"

  function _process_pool() (
    set -euo pipefail
    local np=$1
    local -a nodes=("${(@f)$(z:gke:np:nodes $np)}")
    ((${#nodes[@]} == 1)) && [[ -z ${nodes[1]} ]] && nodes=()

    if ((${#nodes[@]} == 0)); then
      log::info "Node pool $np has 0 nodes — deleting directly"
      z:gke:np:do delete $np "${gcloud_yes_args[@]}" || return 1
      return
    fi

    if $taint_pool; then
      # Appends the draining taint to whatever the pool already has.
      log::info "Appending taint zebradil.dev/draining=true:NoSchedule to node pool $np ..."
      local merged_taints
      merged_taints=$(
        z:gke:np:do describe $np --format=json \
          | jq -r '
              (.config.taints // [])
              | map(select(
                  .key != "zebradil.dev/draining"
                  and (.key | startswith("kubernetes.io/") | not)
                  and (.key | startswith("node.kubernetes.io/") | not)
                  and (.key | startswith("node-role.kubernetes.io/") | not)
                ))
              | map("\(.key)=\(.value):" + (
                  {NO_SCHEDULE:"NoSchedule",
                   PREFER_NO_SCHEDULE:"PreferNoSchedule",
                   NO_EXECUTE:"NoExecute"}[.effect] // .effect))
              + ["zebradil.dev/draining=true:NoSchedule"]
              | join(",")
            '
      ) || return 1
      z:gke:np:do update $np --node-taints="$merged_taints" --quiet || return 1
    fi

    log::info "Disabling autoscaling and autorepair on node pool $np ..."
    # Workaround for fantom autoscaling noticed in GKE v1.35: before disabling autoscaling set max nodes to 0
    z:gke:np:do update $np --total-min-nodes=0 --total-max-nodes=0 "${gcloud_yes_args[@]}" || return 1
    z:gke:np:do update $np --no-enable-autoscaling "${gcloud_yes_args[@]}" || return 1
    z:gke:np:do update $np --no-enable-autorepair "${gcloud_yes_args[@]}" || return 1

    log::info "Draining and deleting ${#nodes[@]} node(s) in node pool $np ..."
    # set -e is suppressed when this function runs inside a conditional (`if _process_pool`),
    # so critical commands need explicit exit-code checks.
    if ! printf '%s\n' "${nodes[@]}" | drain-nodes --delete "${drain_args[@]}"; then
      log::error "drain-nodes failed for node pool $np — aborting pool deletion"
      return 1
    fi

    log::info "Verifying node pool $np has no unexpected nodes before deletion ..."
    local -a remaining=("${(@f)$(z:gke:np:nodes $np)}")
    ((${#remaining[@]} == 1)) && [[ -z ${remaining[1]} ]] && remaining=()

    local -A processed=()
    local n
    for n in "${nodes[@]}"; do processed[$n]=1; done
    local -a unexpected=()
    for n in "${remaining[@]}"; do
      [[ -z ${processed[$n]:-} ]] && unexpected+=("$n")
    done

    if ((${#unexpected[@]} > 0)); then
      log::error "Refusing to delete node pool $np: ${#unexpected[@]} unexpected node(s) present (not part of the originally-drained set):"
      printf '  - %s\n' "${unexpected[@]}" >&2
      return 1
    fi

    if ((${#remaining[@]} > 0)); then
      log::info "Node pool $np has ${#remaining[@]} lingering K8s Node object(s) from drained nodes; proceeding (cloud-controller-manager will GC them)."
    fi

    log::info "Deleting node pool $np ..."
    z:gke:np:do delete $np "${gcloud_yes_args[@]}" || return 1
  )

  local total=${#resolved[@]}
  local idx=0
  local np
  local -a succeeded=() failed=()
  for np in "${resolved[@]}"; do
    ((++idx))
    log::info "===== Processing node pool $np ($idx/$total) ====="

    local slack_ts="" slack_text=""
    if $notify; then
      local -a nodes_preview=("${(@f)$(z:gke:np:nodes $np 2>/dev/null)}")
      ((${#nodes_preview[@]} == 1)) && [[ -z ${nodes_preview[1]} ]] && nodes_preview=()
      local node_count=${#nodes_preview[@]}
      if ((node_count == 0)); then
        slack_text="${ZNIX_SLACK_USER_HANDLE:+${ZNIX_SLACK_USER_HANDLE} }:progress-bubble: Deleting empty node pool \`${np}\` in \`${cluster_name}\` cluster."
      else
        slack_text="${ZNIX_SLACK_USER_HANDLE:+${ZNIX_SLACK_USER_HANDLE} }:progress-bubble: Draining and deleting node pool \`${np}\` in \`${cluster_name}\` cluster (${node_count} node(s))."
      fi
      slack_ts=$(z:slack:post "$slack_token" "$notify_channel" "$slack_text") || slack_ts=""
    fi

    if _process_pool "$np"; then
      [[ -n $slack_ts ]] && z:slack:update "$slack_token" "$notify_channel" "$slack_ts" "${slack_text//:progress-bubble:/:check:}" || true
      succeeded+=("$np")
    else
      [[ -n $slack_ts ]] && z:slack:update "$slack_token" "$notify_channel" "$slack_ts" "${slack_text//:progress-bubble:/:x:}" || true
      log::error "Failed to process node pool $np"
      failed+=("$np")
    fi
  done

  if $notify; then
    local summary_icon summary_text
    if ((${#failed[@]} == 0)); then
      summary_icon=":check:"
      summary_text="${ZNIX_SLACK_USER_HANDLE:+${ZNIX_SLACK_USER_HANDLE} }${summary_icon} Finished draining \`${cluster_name}\`: ${#succeeded[@]}/${total} node pool(s) processed successfully."
    else
      summary_icon=":x:"
      local failed_list="${(j:, :)${failed[@]/#/\`}/%/\`}"
      summary_text="${ZNIX_SLACK_USER_HANDLE:+${ZNIX_SLACK_USER_HANDLE} }${summary_icon} Finished draining \`${cluster_name}\`: ${#succeeded[@]}/${total} succeeded, ${#failed[@]} failed (${failed_list})."
    fi
    z:slack:post "$slack_token" "$notify_channel" "$summary_text" >/dev/null || true
  fi

  ((${#failed[@]} > 0)) && return 1
  return 0
)

function z:gke:node:select() (
  set -euo pipefail

  local list selected
  list=$(kubectl get node -owide)
  if [[ -z $list ]]; then
    return 1
  fi

  selected=$(echo "$list" | fzf --header-lines=1 --no-multi | awk '{print $1}')
  if [[ -z $selected ]]; then
    log::error "No node pool selected"
    return 1
  fi

  echo "$selected"
)

function z:gke:node:ssh() (
  set -euo pipefail

  local node=${1:?node name missing, use - to select}
  if [[ $node == "-" ]]; then
    node=$(z:gke:node:select)
  fi
  if [[ -z $node ]]; then
    return 1
  fi

  local zone
  zone=$(kubectl get node "$node" -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}')
  if [[ -z $zone ]]; then
    return 1
  fi

  local cluster_name project_id region info
  info=$(z:gke:cluster:info)
  if [[ -z $info ]]; then
    return 1
  fi
  read -r cluster_name project_id region <<<"$info"
  log::info "SSH-ing into $node of $cluster_name..."

  gcloud compute ssh "$node" \
    --project="$project_id" \
    --zone="$zone" \
    --tunnel-through-iap
)
