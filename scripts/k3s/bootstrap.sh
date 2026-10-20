#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# Bootstrap Script for k3s installation
# --------------------------------------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

source "$SCRIPT_DIR/../kubecfg.sh"
kubecfg

# --------------------------------------------------
# Versions / configuration
# --------------------------------------------------
CILIUM_VERSION="${CILIUM_VERSION:-1.20.3}"
CERT_MANAGER_VERSION="${CERT_MANAGER_VERSION:-v1.21.2}"
COREDNS_VERSION="${COREDNS_VERSION:-1.49.0}"
TRAEFIK_CHART_VERSION=""

# --------------------------------------------------
# Helpers
# --------------------------------------------------
info() {
  printf '\n[INFO] %s\n' "$1"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf '[ERROR] Required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

for cmd in kubectl helm sops; do
  require_command "$cmd"
done

# --------------------------------------------------
# Kubernetes connection / node labels
# --------------------------------------------------
info "Checking Kubernetes connection"
kubectl get nodes

info "Ensuring worker-node labels"
for node in coreos-worker1 coreos-worker2 coreos-worker3; do
  if kubectl get node "$node" >/dev/null 2>&1; then
    kubectl label node "$node" node-role.kubernetes.io/worker=true --overwrite
  else
    printf '[WARN] Node %s not found; skipping worker label.\n' "$node" >&2
  fi
done

# --------------------------------------------------
# Helm repositories
# --------------------------------------------------
info "Adding / updating Helm repositories"
helm repo add cilium https://helm.cilium.io/ --force-update
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo add traefik https://traefik.github.io/charts --force-update
helm repo add coredns https://coredns.github.io/helm --force-update
helm repo update

# --------------------------------------------------
# Cilium Network und Hubble UI
# VXLAN Overlay: For network isolation, mobility, and Layer 2 connectivity across Layer 3 networks.
# Native Routing: For higher performance, lower latency, and less overhead when direct routing is possible.
# --------------------------------------------------
info "Installing/upgrading Cilium ${CILIUM_VERSION}"

# CILIUM_VALUES="infrastructure/cilium/values_native.yaml"
CILIUM_VALUES="infrastructure/cilium/values_vxlan.yaml"

helm upgrade --install cilium cilium/cilium \
  --namespace kube-system \
  --version "$CILIUM_VERSION" \
  --values "$CILIUM_VALUES"

kubectl rollout status daemonset/cilium -n kube-system --timeout=300s
kubectl rollout status deployment/cilium-operator -n kube-system --timeout=300s

kubectl apply -f "infrastructure/cilium/hubble-ui-ingress.yaml"
kubectl apply -f "infrastructure/cilium/server-certificate.yaml"

# --------------------------------------------------
# CoreDNS
# --------------------------------------------------
info "Installing/upgrading CoreDNS ${COREDNS_VERSION}"

helm upgrade --install coredns coredns/coredns \
  --namespace kube-system \
  --create-namespace \
  --version "${COREDNS_VERSION}" \
  --values "infrastructure/coredns/values.yaml"

kubectl rollout status deployment/coredns -n kube-system --timeout=300s

# --------------------------------------------------
# Cert-Manager
# --------------------------------------------------
info "Installing/upgrading cert-manager ${CERT_MANAGER_VERSION}"
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version "$CERT_MANAGER_VERSION" \
  --set crds.enabled=true \
  --set crds.keep=true \
  --set startupapicheck.enabled=false

info "Waiting for cert-manager deployments"
kubectl rollout status deployment/cert-manager -n cert-manager --timeout=300s
kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=300s
kubectl rollout status deployment/cert-manager-cainjector -n cert-manager --timeout=300s

info "Applying Root CA and Sub-CA resources"
kubectl apply -k "infrastructure/cert-manager"

info "Waiting for Root CA and Sub-CA certificates"
kubectl wait --for=condition=Ready certificate/htdom-root-ca -n cert-manager --timeout=300s
kubectl wait --for=condition=Ready certificate/htdom-sub-ca -n cert-manager --timeout=300s

# --------------------------------------------------
# Traefik
# --------------------------------------------------
info "Installing/upgrading Traefik"
traefik_args=(
  upgrade --install traefik traefik/traefik
  --namespace traefik
  --create-namespace
  --values "infrastructure/traefik/values.yaml"
)
if [[ -n "$TRAEFIK_CHART_VERSION" ]]; then
  traefik_args+=(--version "$TRAEFIK_CHART_VERSION")
fi
helm "${traefik_args[@]}"
kubectl rollout status deployment/traefik -n traefik --timeout=300s

# --------------------------------------------------
# Finished
# --------------------------------------------------
info "Bootstrap completed successfully"
printf '\nBootstrap completed successfully\n'
