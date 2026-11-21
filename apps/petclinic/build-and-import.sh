#!/usr/bin/env bash
# ----------------------------------------------------------------
# Petclinic JVM-Image bauen und direkt in containerd der Worker importieren
# ----------------------------------------------------------------
set -euo pipefail

: "${PETCLINIC_SRC:?PETCLINIC_SRC nicht gesetzt (.envrc)}"
: "${PETCLINIC_COMMIT:?PETCLINIC_COMMIT nicht gesetzt (.envrc)}"
: "${PETCLINIC_IMAGE:?PETCLINIC_IMAGE nicht gesetzt (.envrc)}"
: "${PETCLINIC_PLATFORM:?PETCLINIC_PLATFORM nicht gesetzt (.envrc)}"
: "${K8S_WORKER_HOSTS:?K8S_WORKER_HOSTS nicht gesetzt (.envrc)}"
: "${K8S_SSH_USER:?K8S_SSH_USER nicht gesetzt (.envrc)}"
: "${K8S_SSH_KEY:?K8S_SSH_KEY nicht gesetzt (.envrc)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARBALL="$(mktemp -t petclinic-XXXXXX.tar)"
SSH_OPTS=(-i "${K8S_SSH_KEY}" -o StrictHostKeyChecking=accept-new)

trap 'rm -f "${TARBALL}"' EXIT

# ----------------------------------------------------------------
# Quellcode auf den gewünschten Stand bringen
# ----------------------------------------------------------------
if [[ ! -d "${PETCLINIC_SRC}/.git" ]]; then
  git clone https://github.com/spring-projects/spring-petclinic.git "${PETCLINIC_SRC}"
fi
git -C "${PETCLINIC_SRC}" fetch --quiet origin
git -C "${PETCLINIC_SRC}" checkout --quiet "${PETCLINIC_COMMIT}"

# ----------------------------------------------------------------
# Image bauen und als Tarball speichern
# ----------------------------------------------------------------
docker build \
  --platform "${PETCLINIC_PLATFORM}" \
  -f "${SCRIPT_DIR}/Dockerfile" \
  -t "${PETCLINIC_IMAGE}" \
  "${PETCLINIC_SRC}"

docker save "${PETCLINIC_IMAGE}" -o "${TARBALL}"

# ----------------------------------------------------------------
# Auf jeden Worker kopieren und in den k8s.io-Namespace importieren
# ----------------------------------------------------------------
for host in ${K8S_WORKER_HOSTS}; do
  echo "Importiere auf ${host} ..."
  scp "${SSH_OPTS[@]}" "${TARBALL}" "${K8S_SSH_USER}@${host}:/tmp/petclinic.tar"
  ssh "${SSH_OPTS[@]}" "${K8S_SSH_USER}@${host}" \
    "sudo ctr -n k8s.io images import /tmp/petclinic.tar && rm -f /tmp/petclinic.tar"
  # Kontrolle: Image muss in containerd sichtbar sein
  ssh "${SSH_OPTS[@]}" "${K8S_SSH_USER}@${host}" \
    "sudo ctr -n k8s.io images ls -q | grep -F '${PETCLINIC_IMAGE}'"
done

echo "Fertig: ${PETCLINIC_IMAGE} auf allen Workern importiert."
