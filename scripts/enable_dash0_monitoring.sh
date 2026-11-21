#!/usr/bin/env bash
# ----------------------------------------------------------------
# Dash0 Monitoring für alle Namespaces (System-Namespaces ohne Instrumentation)
# ----------------------------------------------------------------
set -euo pipefail

# Namespace des Operators selbst auslassen
EXCLUDE="dash0-system"
# Kubernetes-System-Namespaces: nur mode none erlaubt
SYSTEM_NS="kube-system kube-public kube-node-lease"

for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  [[ " ${EXCLUDE} " == *" ${ns} "* ]] && continue

  # vorhandene Resourcen (z. B. petclinic per Kustomize) nicht überschreiben
  if [[ -n "$(kubectl get dash0monitoring -n "${ns}" -o name 2>/dev/null)" ]]; then
    echo "skip ${ns} (Dash0Monitoring existiert bereits)"
    continue
  fi

  mode="all"
  [[ " ${SYSTEM_NS} " == *" ${ns} "* ]] && mode="none"

  echo "aktiviere ${ns} (mode: ${mode})"
  cat <<EOF | kubectl apply -f -
apiVersion: operator.dash0.com/v1beta1
kind: Dash0Monitoring
metadata:
  name: dash0-monitoring
  namespace: ${ns}
spec:
  instrumentWorkloads:
    mode: ${mode}
  logCollection:
    enabled: true
  eventCollection:
    enabled: true
  prometheusScraping:
    enabled: true
EOF
done
