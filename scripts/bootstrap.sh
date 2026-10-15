#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/kubecfg.sh"
kubecfg

# --------------------------------------------------
# Variables
# --------------------------------------------------
CERT_MANAGER_VERSION="v1.21.2"

# --------------------------------------------------
# Helper
# --------------------------------------------------
info() {
  echo
  echo "[INFO] $1"
}

# --------------------------------------------------
# Kubeconfig
# --------------------------------------------------
info "Checking Kubernetes connection"
kubectl get nodes

# --------------------------------------------------
# Worker node labeling
# --------------------------------------------------
kubectl get nodes -o name \
  | grep '^node/coreos-worker' \
  | while read -r node; do
      kubectl label "$node" node-role.kubernetes.io/worker=true --overwrite
    done

# --------------------------------------------------
# ConfigMap coredns to reduce log entries
# --------------------------------------------------
info "ConfigMap coredns"
kubectl apply -f infrastructure/coredns/coredns-custom.yaml

# --------------------------------------------------
# Node Log Collector
# --------------------------------------------------
# info "Node Log Collector"
# kubectl apply -f apps/node-log-collector/daemonset.yaml

# --------------------------------------------------
# Helm repositories
# --------------------------------------------------
info "Adding Helm repositories"
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo add cnpg https://cloudnative-pg.github.io/charts --force-update
helm repo update

# --------------------------------------------------
# Cert-Manager
# --------------------------------------------------
info "Installing cert-manager"
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version "${CERT_MANAGER_VERSION}" \
  --set crds.enabled=true \
  --set crds.keep=true \
  --set startupapicheck.enabled=false

# --------------------------------------------------
# CloudNativePG - PostgreSQL Operator for Kubernetes
# --------------------------------------------------
info "Installing CloudNativePG"
helm upgrade --install cnpg cnpg/cloudnative-pg --namespace cnpg-system --create-namespace

# --------------------------------------------------
# Wait for deployments
# --------------------------------------------------
info "Waiting for cert-manager"
kubectl rollout status deployment/cert-manager -n cert-manager --timeout=300s
kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=300s
kubectl rollout status deployment/cert-manager-cainjector -n cert-manager --timeout=300s

# --------------------------------------------------
# Create Root and Sub-CA
# --------------------------------------------------
info "Installing Root and Sub-CA"
kubectl apply -k infrastructure/cert-manager

# --------------------------------------------------
# Yelb secrets deployment
# --------------------------------------------------
info "Installing yelb secrets"
kubectl apply -f apps/yelb/namespace.yaml
sops -d secrets/yelb-db-secret.yaml | kubectl apply -f -

# --------------------------------------------------
# forgejo secrets deployment
# --------------------------------------------------
info "Installing forgejo secrets"
kubectl apply -f apps/forgejo/namespace.yaml
sops -d secrets/forgejo-db-secret.yaml | kubectl apply -f -
sops -d secrets/forgejo-admin-secret.yaml | kubectl apply -f -

# --------------------------------------------------
# Finished
# --------------------------------------------------
info "Bootstrap completed successfully"
