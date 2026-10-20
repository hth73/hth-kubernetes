# Kubernetes Clusters with K3s

<p>
  <img src="images/k8s_setup.jpg" width="50%" height="50%" />
</p>

<img src="https://img.shields.io/badge/VirtualBox-2F61B4?style=flat&logo=virtualbox&labelColor=ffffff&logoColor=2F61B4" /> <img src="https://img.shields.io/badge/Fedora%20CoreOS-51A2DA?style=flat&logo=fedora&labelColor=ffffff&logoColor=5277C3" /> <img src="https://img.shields.io/badge/Kubernetes-326CE5?style=flat&logo=kubernetes&labelColor=ffffff&logoColor=326CE5" /> <img src="https://img.shields.io/badge/Cilium-F8C517?style=flat&logo=cilium&labelColor=ffffff&logoColor=F8C517" /> <img src="https://img.shields.io/badge/Traefik-24A1C1?style=flat&logo=traefikproxy&labelColor=ffffff&logoColor=24A1C1" /> <img src="https://img.shields.io/badge/Cert%20Manager-326CE5?style=flat&logo=kubernetes&labelColor=ffffff&logoColor=326CE5" /> <img src="https://img.shields.io/badge/Headlamp-326CE5?style=flat&logo=kubernetes&labelColor=ffffff&logoColor=326CE5" /> <img src="https://img.shields.io/badge/ArgoCD-EF7B4D?style=flat&logo=argo&labelColor=ffffff&logoColor=EF7B4D" /> <img src="https://img.shields.io/badge/Helm-0F1689?style=flat&logo=helm&labelColor=ffffff&logoColor=0F1689" /> <img src="https://img.shields.io/badge/TrueNAS-0095D5?style=flat&logo=truenas&labelColor=ffffff&logoColor=0095D5" /> <img src="https://img.shields.io/badge/SOPS-3e484d?style=flat&logo=gnuprivacyguard&labelColor=ffffff&logoColor=3e484d" />
---

### Inhaltsverzeichnis

* [Cert Manager](infrastructure/cert-manager/README.md)
* [etcd - key-value store](infrastructure/etcd/README.md)
* [Node Log Collector - DaemonSet](apps/node-log-collector/README.md)
* [Headlamp Kubernetes UI](infrastructure/dashboard/README.md)
* [Argo CD – GitOps im Kubernetes](infrastructure/argocd/README.md)
* [Kustomize – Kubernetes-Manifeste verwalten](infrastructure/kustomize/README.md)
* [Popeye Kubernetes Live Cluster Linter](infrastructure/popeye/README.md)
* [TrueNAS ISCSI LUNs](infrastructure/iscsi-storage/README.md)
  * [Forgejo Git Server](apps/forgejo/srv/README.md)
  * [Petclinic Demo Application](apps/petclinic/README.md)
  * [Podinfo Demo Application](apps/podinfo/README.md)
  * [yelb Demo Application](apps/yelb/README.md)
  * [Todo List Demo Application](apps/todo/README.md)

---

## Beschreibung

Der Kubernetes-Cluster besteht aus:
- 1-3 Control Plane Master Nodes mit embedded etcd
- 2-3 Worker Nodes
- Cilium mit einem VXLAN-Overlay-Netzwerk
- CoreDNS über Helm Charts
- Cert-Manager für TLS/SSL-Zertifikate
- Traefik über Helm Charts
- Hubble UI Observability-Plattform
- Headlamp Kubernetes Dashboard
- Argo CD für Continuous Delivery

## Aufbau des K3s-Kubernetes-Clusters

Für den Aufbau eines K3s-Kubernetes-Clusters werden zwei Repositories und eine funktionierende VirtualBox-Umgebung benötigt.

* [CoreOS Linux Unattended Installation](https://github.com/hth73/hth-ansible-wks)
* [Kubernetes Homelab](https://github.com/hth73/hth-kubernetes)

### Optional: iSCSI-Storage installieren
 * [TrueNAS & iSCSI Storage für Kubernetes](https://github.com/hth73/hth-kubernetes/blob/main/infrastructure/iscsi-storage/README.md)

### Vorbereitung für das CoreOS Image

```bash
# --------------------------------------------------
# Repositories klonen
# --------------------------------------------------
mkdir -p ~/repos && cd ~/repos
git clone https://github.com/hth73/hth-ansible-wks.git
git clone https://github.com/hth73/hth-kubernetes.git

# --------------------------------------------------
# SSH-Key ohne Passphrase für das Deployment erstellen
# --------------------------------------------------
cd hth-ansible-wks
ssh-keygen -o -t ed25519 -f secrets/ssh/id_ed25519 -C'ansible@accesskey'

# --------------------------------------------------
# CoreOS-ISO-Image herunterladen und den "iso_path" in packer/coreos/coreos.pkr.hcl anpassen
# --------------------------------------------------
mkdir iso
wget -O iso/fedora-coreos-44.20260928.3.1-live-iso.x86_64.iso https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/44.20260928.3.1/x86_64/fedora-coreos-44.20260928.3.1-live-iso.x86_64.iso
```

### CoreOS-Ignition-Datei anpassen
```bash
# --------------------------------------------------
# CoreOS-Butane-Binary lokal installieren
# --------------------------------------------------
sudo wget -O /usr/local/bin/butane https://github.com/coreos/butane/releases/download/v0.29.0/butane-x86_64-unknown-linux-gnu
chmod +x ~/usr/local/bin/butane

butane --version
# Butane 0.29.0

# --------------------------------------------------
# Alle gewünschten öffentlichen SSH-Keys in packer/coreos/config/ansible_config.bu kopieren.
# --------------------------------------------------
cat secrets/ssh/id_ed25519.pub 
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN2X1sQYiP/jSE8CWG+FXKjDYJcfic4mALW71fVB7SfC

# --- packer/coreos/config/ansible_config.bu
# Fedora CoreOS Ansible Butane configuration
# Date: 2026-05-20

variant: fcos
version: 1.6.0

passwd:
 users:
   # Default User core
   - name: core
     ssh_authorized_keys:
       - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN2X1sQYiP/jSE8CWG+FXKjDYJcfic4mALW71fVB7SfC
       - ssh-ed25519 AAAA.....lT

# --------------------------------------------------
# packer/coreos/config/ansible_config.bu in eine Ignition-Datei konvertieren
# -------------------------------------------------- 
butane --pretty --strict packer/coreos/config/ansible_config.bu > packer/coreos/config/ansible_config.ign

# --------------------------------------------------
# Create an ignition checksum and use it in Packer
# --------------------------------------------------
sha256sum packer/coreos/config/ansible_config.ign
# 3834f44c52b0b80e..........
# or
sha512sum packer/coreos/config/ansible_config.ign
# 9c4f683ab01ca78f..........

# --------------------------------------------------
# Checksumme in packer/coreos/coreos.pkr.hcl anpassen
# --------------------------------------------------
...

variable "ignition_hash" {
  type    = string
  default = "sha256-3834f44c52b0b80e.........."
  # default = "sha512-9c4f683ab01ca78f.........."
}
```

### CoreOS-Basis-Image mit Packer erstellen
```bash
cd hth-ansible-wks/packer/coreos

packer init coreos.pkr.hcl
packer validate coreos.pkr.hcl
packer build coreos.pkr.hcl
```

### CoreOS-VMs bereitstellen
```bash
cd hth-ansible-wks/vagrant/coreos

# --------------------------------------------------
# Vagrantfile_k3s_cluster bei Bedarf anpassen
# --------------------------------------------------
vagrant box add ../../packer/coreos/coreos-base.box --name coreos-base --force
export VAGRANT_VAGRANTFILE=Vagrantfile_k3s_cluster

vagrant validate
# Vagrantfile validated successfully.

vagrant up
```

## SOPS: Secrets OPerationS integration

```bash
# --------------------------------------------------------------------------------
# SOPS installation
# https://getsops.io - https://github.com/getsops
# --------------------------------------------------------------------------------
cd /tmp
wget https://github.com/getsops/sops/releases/download/v3.13.3/sops-v3.13.3.linux.amd64
mv sops-v3.13.3.linux.amd64 ~/bin/sops
chmod +x ~/bin/sops

sops --version --check-for-updates
sops 3.13.3 (latest)

# --------------------------------------------------------------------------------
# Set up sops with age and age-keygen
# https://github.com/FiloSottile/age
# --------------------------------------------------------------------------------
wget https://github.com/FiloSottile/age/releases/download/v1.3.2/age-v1.3.2-linux-amd64.tar.gz
tar xvf age-v1.3.2-linux-amd64.tar.gz
mv age/age ~/bin
mv age/age-keygen ~/bin

age -version
age-keygen -version

# ---

mkdir ~/.sops
age-keygen -o ~/.sops/sops_key.txt

cat ~/.sops/sops_key.txt
# created: xxx
# public key: age13..................................
# AGE-SECRET-KEY-....................................

vi ~/.zshrc
export SOPS_AGE_KEY_FILE="${HOME}/.sops/sops_key.txt"
```

### SOPS für Kubernetes konfigurieren

```bash
## Create a folder and a sops rule file
mkdir secrets

## add the public age key from the file "cat ~/.sops/sops_key.txt"
vi .sops.yaml
# ---
# creation_rules:
#   - path_regex: secrets/.*\.ya?ml$
#     encrypted_regex: '^(data|stringData|password|PASSWD|token|secret|ssh_keys)$'
#     age: age13..................................
```

### Abschließende Installationsschritte für das K3s-Cluster

Für die Installation der restlichen Komponenten wurde ein `Makefile` erstellt.

**Wichtig:** Während der Installation wird in der Konsole nach dem eigenen `sudo`-Passwort gefragt. Auf Debian-Systemen werden damit die Root- und Sub-CA-Zertifikate von Cert-Manager ins System installiert. Zusätzlich werden die Dateien `htdom-root-ca.crt` und `htdom-sub-ca.crt` im diesem Root-Verzeichnis abgelegt. Diese können in den Browser importiert werden, um eine gültige Zertifikatsvertrauenskette herzustellen. Anschließend werden die Anwendungen im Cluster im Browser ohne Zertifikatsfehler dargestellt.

Alle Anwendungen werden mit dem Domain-Suffix `*.htdom.lan` installiert. Sollte man dieses ändern wollen, müssen die entsprechenden Serverzertifikate und Ingress-Dateien der jeweiligen Anwendungen angepasst werden.

Wenn die Root-/Sub-CA unter einem eigenen Namen installiert werden soll, müssen auch die Dateien in `./infrastructure/cert-manager` angepasst werden.

- dashboard.htdom.lan
- argo.htdom.lan
- podinfo.htdom.lan
- hubble.htdom.lan

```bash
# --------------------------------------------------
# /etc/hosts anpassen.
# Der Traefik Einstiegspunkt ist immer coreos-worker1 oder coreos-worker2
# --------------------------------------------------
sudo vi /etc/hosts                              
# ...

192.168.56.13 argo.htdom.lan
192.168.56.13 dashboard.htdom.lan
192.168.56.13 hubble.htdom.lan
192.168.56.13 podinfo.htdom.lan

oder

192.168.56.14 argo.htdom.lan
192.168.56.14 dashboard.htdom.lan
192.168.56.15 hubble.htdom.lan
192.168.56.14 podinfo.htdom.lan
```

Das bereitgestellte `Makefile` verwendet ein Bash-Skript `./scripts/k3s/bootstrap.sh`, um die Kernkomponenten zu installieren und weitere Tooling-Aufgaben auszuführen.

- Cilium mit einem VXLAN-Overlay-Netzwerk
- Hubble UI Observability-Plattform
- CoreDNS-Server
- Traefik-Server
- cert-manager
- Headlamp-Dashboard
- Argo CD für Continuous Delivery

```bash
make help
# Available targets:
#   make k3s              Install K3s setup
#   make k8s              Install kubeadm Kubernetes setup
#   make all              Same as make k8s
#   make bootstrap-k3s    Bootstrap K3s infrastructure
#   make bootstrap-k8s    Bootstrap kubeadm infrastructure
#   make export-ca-certs  Export CA certificates
#   make deploy-podinfo   Deploy Podinfo
#   make deploy-headlamp  Deploy Headlamp
#   make deploy-argocd    Install Argo CD

make k3s
```

### Token für Headlamp Dashboard erzeugen

```bash
kubectl create token dashboard -n dashboard               
# eyJhbGciOiJSUzI1NiIsImtpZCI6Ijg5Z
```

### Initial Passwort für ArgoCD ausgeben

```bash
# --------------------------------------------------
# Initial Passwort ausgeben (Username: admin)
# --------------------------------------------------
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 --decode
# 3nSKlC8Kfxxxxxxxx

# --------------------------------------------------
# Nach Passwort Änderung in ArgoCD, das Initial Password in K3s löschen
# --------------------------------------------------
kubectl delete secret argocd-initial-admin-secret -n argocd
kubectl get secret argocd-initial-admin-secret -n argocd
```

Um auf das Kubernetes-Cluster zugreifen zu können, wird zunächst die Kubernetes-Client-Konfigurationsdatei benötigt. Sie wird lokal unter `$HOME/.kube/config` abgelegt. 

```bash
# --------------------------------------------------
# SSH-Key laden
# --------------------------------------------------
eval "$(ssh-agent -s)"
ssh-add ~/repos/hth-ansible-wks/secrets/ssh/id_ed25519

mkdir -p "$HOME/.kube"
umask 077

ssh core@192.168.56.10 'sudo cat /etc/rancher/k3s/k3s.yaml' |
  sed 's#https://127.0.0.1:6443#https://192.168.56.10:6443#' \
  > "$HOME/.kube/config"

chmod 600 "$HOME/.kube/config"

cat "$HOME/.kube/config"
```

Wenn für jeden Master-Node eine eigene Kubeconfig gewünscht ist, lässt sich dies mit einer kleinen Funktion in `~/.bashrc` oder `~/.zshrc` umsetzen.

```bash
# --------------------------------------------------
# Funktion zum Laden der Kubeconfig
# --------------------------------------------------
function m1() {
  local kubeconfig="$HOME/.kube/coreos-master1"
  if [[ ! -f "$kubeconfig" ]]; then
    echo "Fetching kubeconfig from coreos-master1 ..."
    umask 077
    ssh core@192.168.56.10 'sudo cat /etc/rancher/k3s/k3s.yaml' |
      sed \
        -e 's#https://127.0.0.1:6443#https://192.168.56.10:6443#' \
        -e '/^clusters:/,/^users:/ s/name: default/name: coreos-master1/' \
        -e '/^users:/,/^contexts:/ s/name: default/name: coreos-master1-admin/' \
        -e '/^contexts:/,$ s/name: default/name: coreos-master1/' \
        -e '/^contexts:/,$ s/cluster: default/cluster: coreos-master1/' \
        -e '/^contexts:/,$ s/user: default/user: coreos-master1-admin/' \
        -e 's/^current-context: default$/current-context: coreos-master1/' \
      > "$kubeconfig"
  fi
  export KUBECONFIG="$kubeconfig"
  clear
}

function m2() {
  local kubeconfig="$HOME/.kube/coreos-master2"
  if [[ ! -f "$kubeconfig" ]]; then
    echo "Fetching kubeconfig from coreos-master2 ..."
    umask 077
    ssh core@192.168.56.11 'sudo cat /etc/rancher/k3s/k3s.yaml' |
      sed \
        -e 's#https://127.0.0.1:6443#https://192.168.56.11:6443#' \
        -e '/^clusters:/,/^users:/ s/name: default/name: coreos-master2/' \
        -e '/^users:/,/^contexts:/ s/name: default/name: coreos-master2-admin/' \
        -e '/^contexts:/,$ s/name: default/name: coreos-master2/' \
        -e '/^contexts:/,$ s/cluster: default/cluster: coreos-master2/' \
        -e '/^contexts:/,$ s/user: default/user: coreos-master2-admin/' \
        -e 's/^current-context: default$/current-context: coreos-master2/' \
      > "$kubeconfig"
  fi
  export KUBECONFIG="$kubeconfig"
  clear
}

function m3() {
# ...
```

Alternativ lassen sich die einzelnen Kubeconfigs zu einer Datei zusammenführen. Anschließend muss nur noch der gewünschte Kontext ausgewählt werden.

```bash
KUBECONFIG="$HOME/.kube/coreos-master1:$HOME/.kube/coreos-master2:$HOME/.kube/coreos-master3" \
  kubectl config view --merge --flatten \
  > "$HOME/.kube/config"

chmod 600 "$HOME/.kube/config"

export KUBECONFIG="$HOME/.kube/config"

kubectl config get-contexts
# CURRENT   NAME             CLUSTER          AUTHINFO               NAMESPACE
# *         coreos-master1   coreos-master1   coreos-master1-admin   
#           coreos-master2   coreos-master2   coreos-master2-admin
#           coreos-master3   coreos-master3   coreos-master3-admin

kubectl config current-context
# coreos-master1

kubectl config use-context coreos-master2               
# Switched to context "coreos-master2".

kubectl config current-context           
# coreos-master2
```

Ab jetzt kann man mit `kubectl` oder `k9s` auf das Kubernetes-Cluster zugreifen und die ersten Tests durchgeführt werden.

```bash
kubectl get nodes       
# NAME             STATUS   ROLES                AGE     VERSION
# coreos-master1   Ready    control-plane,etcd   2d15h   v1.36.5+k3s1
# coreos-master2   Ready    control-plane,etcd   2d15h   v1.36.5+k3s1
# coreos-master3   Ready    control-plane,etcd   2d15h   v1.36.5+k3s1
# coreos-worker1   Ready    worker               2d15h   v1.36.5+k3s1
# coreos-worker2   Ready    worker               2d15h   v1.36.5+k3s1

kubectl get namespaces 
# NAME              STATUS   AGE
# default           Active   18h
# kube-node-lease   Active   18h
# kube-public       Active   18h
# kube-system       Active   18h

kubectl get services
# NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
# kubernetes   ClusterIP   10.43.0.1    <none>        443/TCP   18h
# ...
```
