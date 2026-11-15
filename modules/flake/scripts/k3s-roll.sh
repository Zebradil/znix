#!/usr/bin/env bash
# Rolling reboot of k3s nodes into their new generation, one node at a time:
# drain, `colmena apply boot --reboot`, wait for the new boot to report Ready,
# uncordon. With no arguments: control-plane nodes first (an agent must never
# run a newer k3s than the server), then the rest. Node names are colmena
# node names (both are the hostname).
# Usage: k3s-roll [NODE...] [-- COLMENA_APPLY_ARGS...]
set -euo pipefail

nodes=()
while (($#)) && [[ $1 != -- ]]; do
  if [[ $1 == -* ]]; then
    echo "usage: k3s-roll [NODE...] [-- COLMENA_APPLY_ARGS...]" >&2
    exit 2
  fi
  nodes+=("$1")
  shift
done
[[ ${1:-} == -- ]] && shift

if ((${#nodes[@]} == 0)); then
  mapfile -t nodes < <(
    kubectl get nodes -l node-role.kubernetes.io/control-plane -o name
    kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o name
  )
  nodes=("${nodes[@]#node/}")
fi

echo "rolling: ${nodes[*]}"
for node in "${nodes[@]}"; do
  echo "== $node"
  boot_id=$(kubectl get node "$node" -o jsonpath='{.status.nodeInfo.bootID}')
  kubectl drain "$node" --ignore-daemonsets --delete-emptydir-data --timeout=15m
  colmena apply boot --reboot --on "$node" "$@"

  # The Ready condition from before the reboot can still be current for up to
  # the node grace period; a new bootID proves kubelet reported from this boot.
  deadline=$((SECONDS + 600))
  # Empty while the apiserver is down (rolling the server); that is not a new boot.
  while new_id=$(kubectl get node "$node" -o jsonpath='{.status.nodeInfo.bootID}' 2>/dev/null || true)
    [[ -z $new_id || $new_id == "$boot_id" ]]; do
    if ((SECONDS > deadline)); then
      echo "$node: no new bootID after 10m; left cordoned" >&2
      exit 1
    fi
    sleep 5
  done
  kubectl wait --for=condition=Ready "node/$node" --timeout=10m
  kubectl uncordon "$node"
done
