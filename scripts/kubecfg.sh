#!/usr/bin/env bash

kubecfg() {
  local kubeconfig="$HOME/.kube/master1"

  mkdir -p "$HOME/.kube"
  umask 077

  if [[ ! -s "$kubeconfig" ]]; then
    echo "[INFO] Fetching kubeconfig from master1..."

    local tmp_file
    tmp_file="$(mktemp "$HOME/.kube/master1.XXXXXX")"
    trap 'rm -f "$tmp_file"' RETURN

    ssh core@192.168.56.10 \
      'sudo cat /etc/rancher/k3s/k3s.yaml' |
      sed \
        -e 's#https://127.0.0.1:6443#https://192.168.56.10:6443#' \
        -e 's/name: default/name: coreos-master1/g' \
        -e 's/cluster: default/cluster: coreos-master1/g' \
        -e 's/user: default/user: coreos-master1/g' \
        -e 's/current-context: default/current-context: coreos-master1/g' \
        > "$tmp_file"

    [[ -s "$tmp_file" ]] || {
      echo "[ERROR] Kubeconfig is empty." >&2
      return 1
    }

    chmod 600 "$tmp_file"
    mv "$tmp_file" "$kubeconfig"
    trap - RETURN
  fi

  export KUBECONFIG="$kubeconfig"
}
