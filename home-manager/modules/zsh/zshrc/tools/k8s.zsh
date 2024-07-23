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

if lib::check_commands stern; then
  source <(stern --completion zsh)
fi

if lib::check_commands kubie; then
  alias kc="kubie ctx"
  alias kn="kubie ns"
fi

if lib::check_commands switcher; then
  source <(switcher init zsh)
  alias s=switch
fi

my:k8s:set_kubeconfig_var() {
  export KUBECONFIG="$(echo ~/.kube/*clusters/*.y?ml(N) | tr ' ' ':')"
}
