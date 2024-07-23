my:kubectl:chroot-node() (
  # Copyright (c) 2019 Gonçalo Baltazar <me@goncalomb.com>
  # MIT License

  # Open a root shell on a Kubernetes cluster Node (no ssh).

  # It uses a privileged container to unlock Linux capabilities and chroot to
  # change into the root filesystem of the Node for full access.

  # The Node is selected using the 'kubernetes.io/hostname' label.

  local NODE_HOSTNAME="${1:?Usage: $0 NODE_HOSTNAME}"

  kubectl run "node-gate-"$NODE_HOSTNAME -it --rm --restart=Never --attach --image=busybox --overrides '
{
	"spec": {
		"nodeSelector": {
			"kubernetes.io/hostname": "'$NODE_HOSTNAME'"
		},
		"hostPID": true,
		"hostIPC": true,
		"hostNetwork": true,
		"containers": [
			{
				"name": "node-gate",
				"image": "busybox",
				"stdin": true,
				"tty": true,
				"command": [
					"chroot", "/mnt/host"
				],
				"securityContext": {
					"privileged": true
				},
				"volumeMounts": [
					{
						"name": "host",
						"mountPath": "/mnt/host"
					}
				]
			}
		],
		"tolerations": [
			{
				"effect": "NoSchedule",
				"operator": "Exists"
			}
		],
		"volumes": [
			{
				"name": "host",
				"hostPath": {
					"path": "/"
				}
			}
		]
	}
}
    '
)

my:kubectl:node-ssh-from-pod() {
  local ctx ns
  local ssh_key
  local node_username

  zparseopts -D -K -E \
    -context:=ctx \
    n:=ns -namespace:=ns \
    i:=ssh_key -identity:=ssh_key \
    l:=node_username -login:=node_username -username:=node_username

  ns=${ns[2]:-$(kubectl::current-namespace)}
  ctx=${ctx[2]:-$(kubectl::current-context)}
  ssh_key=${ssh_key[2]:-${HOME}/.ssh/id_ed25519}
  node_username=${node_username[2]:-core}

  local node="$1" node_ip
  node_ip=$(kubectl --context "$ctx" get node "$node" -o json \
    | jq -er '.metadata.annotations["alpha.kubernetes.io/provided-node-ip"]')
  shift
  local node_cmd="$*"

  if [[ -z "$node_ip" ]]; then
    echo_error "Failed to determine node IP of $node"
    return 1
  fi

  local pod="ssh-node-${USER}-$(date '+%s')"
  echo_info "Starting pod $pod in $ns (ctx: $ctx)"
  # echo_info "Transfer your key: kubectl --context $ctx cp ${ssh_key} ${pod}:id_ed25519"

  trap "kubectl --context "$ctx" delete pod -n $ns $pod --wait=false >&2" EXIT

  setopt localoptions nonotify nomonitor
  {
    sleep 2 # FIXME is this even necessary?
    if kubectl --context "$ctx" --namespace "$ns" wait --for=condition=ready --timeout=5m pod "$pod" >&2; then
      echo_warning "Transfering your PRIVATE KEY (${ssh_key}) to the pod"
      kubectl --context "$ctx" --namespace "$ns" cp "${ssh_key}" "${pod}:id_ed25519"
    fi
  } &

  kubectl --context "$ctx" \
    run "$pod" --rm --restart=Never \
    --quiet \
    --namespace "$ns" \
    --stdin=true --tty=true \
    --force=true --grace-period=1 \
    --labels="owner=${USER},purpose=debug,app=node-ssh-via-pod" \
    --env "node_username=${node_username}" \
    --env "node_ip=${node_ip}" \
    --env "node_cmd=${node_cmd}" \
    --image pschmitt/debug \
    -- \
    -c '
      trap "rm -f /id_ed25519" EXIT;
      while [[ ! -r /id_ed25519 ]]
      do
        echo "Waiting for ssh key to magically appear..." >&2
        sleep 1
      done

      chmod 400 /id_ed25519 && \
        ssh -i /id_ed25519 \
          -o UserKnownHostsFile=/dev/null \
          -o StrictHostKeyChecking=no \
        ${node_username}@${node_ip} $node_cmd;
    rm -f /id_ed25519'
}
