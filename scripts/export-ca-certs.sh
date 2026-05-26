#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Exporting root CA"
kubectl get secret htdom-root-ca-secret -n cert-manager -o jsonpath='{.data.tls\.crt}' | base64 --decode > htdom-root-ca.crt

echo "[INFO] Exporting intermediate CA"
kubectl get secret htdom-sub-ca-secret -n cert-manager -o jsonpath='{.data.tls\.crt}' | base64 --decode > htdom-sub-ca.crt

echo "[INFO] Import Root and Sub-CA Certs to OS Store"
sudo cp htdom-root-ca.crt /usr/share/ca-certificates
sudo cp htdom-sub-ca.crt /usr/share/ca-certificates

sudo cp htdom-root-ca.crt /usr/local/share/ca-certificates
sudo cp htdom-sub-ca.crt /usr/local/share/ca-certificates
sudo update-ca-certificates
