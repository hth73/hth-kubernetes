#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# Variables
# --------------------------------------------------
CERT_MANAGER_VERSION="v1.20.2"

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
# Helm repositories
# --------------------------------------------------
info "Adding Helm repositories"
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo add cnpg https://cloudnative-pg.github.io/charts --force-update
helm repo update

# --------------------------------------------------
# cert-manager
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
# CloudNativePG
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
# Wait for CNPG
# --------------------------------------------------
info "Waiting for CloudNativePG"
kubectl rollout status deployment/cnpg-cloudnative-pg -n cnpg-system --timeout=300s

# --------------------------------------------------
# Finished
# --------------------------------------------------
info "Bootstrap completed successfully"
