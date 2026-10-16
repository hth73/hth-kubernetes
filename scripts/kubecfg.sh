#!/usr/bin/env bash

kubecfg() {
  local kubeconfig="$HOME/.kube/config"

  mkdir -p "$HOME/.kube"
  umask 077

  if [[ ! -s "$kubeconfig" ]]; then
    echo "[INFO] Fetching kubeconfig from master1..."

    local tmp_file
    tmp_file="$(mktemp "$HOME/.kube/master1.XXXXXX")"
    trap 'rm -f "$tmp_file"' RETURN

    ssh core@192.168.56.10 \
      'ssh core@192.168.56.10 'sudo cat /etc/kubernetes/admin.conf' | sed -e 's#https://127.0.0.1:6443#https://192.168.56.10:6443#'' \
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
