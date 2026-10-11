#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/kubecfg.sh"
kubecfg

ROOT_CA_SECRET="htdom-root-ca-secret"
SUB_CA_SECRET="htdom-sub-ca-secret"
NAMESPACE="cert-manager"
SYSTEM_CA_DIR="/usr/share/ca-certificates"
LOCAL_CA_DIR="/usr/local/share/ca-certificates"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

export_cert() {
  local secret="$1"
  local output="$2"

  kubectl get secret "$secret" -n "$NAMESPACE" \
    -o jsonpath='{.data.tls\.crt}' |
    base64 --decode > "$output"

  if [[ ! -s "$output" ]]; then
    echo "[ERROR] Certificate from secret '$secret' is empty." >&2
    exit 1
  fi
}

echo "[INFO] Exporting Root CA"
export_cert "$ROOT_CA_SECRET" "$tmp_dir/htdom-root-ca.crt"

echo "[INFO] Exporting Sub-CA"
export_cert "$SUB_CA_SECRET" "$tmp_dir/htdom-sub-ca.crt"

echo "[INFO] Installing CA certificates into both Ubuntu trust-store locations"
for target_dir in "$SYSTEM_CA_DIR" "$LOCAL_CA_DIR"; do
  sudo install -D -m 0644 "$tmp_dir/htdom-root-ca.crt" \
    "$target_dir/htdom-root-ca.crt"
  sudo install -D -m 0644 "$tmp_dir/htdom-sub-ca.crt" \
    "$target_dir/htdom-sub-ca.crt"
done

echo "[INFO] Updating CA certificate store"
sudo update-ca-certificates

echo "[INFO] CA certificate installation completed"

