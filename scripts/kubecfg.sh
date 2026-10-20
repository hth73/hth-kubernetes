#!/usr/bin/env bash

kubecfg() {
  local kubeconfig="$HOME/.kube/config"

  mkdir -p "$HOME/.kube"
  umask 077

    if ssh core@192.168.56.10 \
      "sudo test -f /etc/kubernetes/admin.conf"; then
      echo "[INFO] Detected kubeadm installation."

      ssh core@192.168.56.10 \
        "sudo cat /etc/kubernetes/admin.conf" \
        | sed -e 's#https://127.0.0.1:6443#https://192.168.56.10:6443#' \
        > "$kubeconfig"

    elif ssh core@192.168.56.10 \
      "sudo test -f /etc/rancher/k3s/k3s.yaml"; then
      echo "[INFO] Detected K3s installation."

      ssh core@192.168.56.10 \
        "sudo cat /etc/rancher/k3s/k3s.yaml" \
        | sed -e 's#https://127.0.0.1:6443#https://192.168.56.10:6443#' \
        > "$kubeconfig"

    else
      echo "[ERROR] No kubeadm or K3s kubeconfig found." >&2
      return 1
    fi

  export KUBECONFIG="$kubeconfig"
}
