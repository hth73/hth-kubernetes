# Kubernetes Clusters from Scratch with kubespray

<p>
  <img src="images/k8s_setup.jpg" width="50%" height="50%" />
</p>

<img src="https://img.shields.io/badge/VirtualBox-2F61B4?style=flat&logo=virtualbox&labelColor=ffffff&logoColor=2F61B4" /> <img src="https://img.shields.io/badge/Fedora%20CoreOS-51A2DA?style=flat&logo=fedora&labelColor=ffffff&logoColor=5277C3" /> <img src="https://img.shields.io/badge/Kubespray-3D647F?style=flat&logo=kubespray&labelColor=ffffff&logoColor=3D647F" /> <img src="https://img.shields.io/badge/Ansible-d5000e?logo=ansible&logoColor=white&style=flat" /> <img src="https://img.shields.io/badge/Kubernetes-326CE5?style=flat&logo=kubernetes&labelColor=ffffff&logoColor=326CE5" /> <img src="https://img.shields.io/badge/Cilium-F8C517?style=flat&logo=cilium&labelColor=ffffff&logoColor=F8C517" />

Diese Dokumentation beschreibt den reproduzierbaren Aufbau eines Kubernetes Clusters auf Fedora CoreOS mit [Kubespray](https://github.com/kubernetes-sigs/kubespray).

Die Anwendungsmanifeste und GitOps liegen im Repository
[`hth-kubernetes`](https://github.com/hth73/hth-kubernetes).

Die Clusterbereitstellung und Kubespray Integration werden im Repository
[`hth-ansible-wks`](https://github.com/hth73/hth-ansible-wks) verwaltet.

## Umgebung

| Knoten           | Rolle                  | IP-Adresse |
| :-------         | :------                | :------- |
| `coreos-master1` | Control Plane und etcd | `192.168.56.10`   |
| `coreos-worker1`   | Worker               | `192.168.56.13`   |
| `coreos-worker2`   | Worker               | `192.168.56.14`   |
                  
Aktueller Stand:
- Fedora CoreOS `44.20260928.3.2`
- Kubernetes `v1.37.1`,
- containerd und Cilium. 

Das Cluster verwendet Cilium Native Routing,
WireGuard-Verschlüsselung und Hubble.
- Pod-CIDR: `172.16.0.0/16`;
- Service-CIDR: `10.96.0.0/12`.

## 1. Provisionierungs-Repository vorbereiten

Repository klonen und das Kubespray-Submodul initialisieren:

``` bash
git clone https://github.com/hth73/hth-ansible-wks.git
cd hth-ansible-wks
git submodule update --init --recursive
```

Kubespray liegt als Upstream Git Submodul unter `kubespray/upstream`.
Das eigene Inventory und die Konfiguration bleiben außerhalb dieses
Verzeichnisses, damit Updates des Upstreams die Konfiguration nicht
überschreiben.

## 2. Ansible-Umgebung einrichten

Für Kubespray wird eine eigene Python-Umgebung verwendet:

``` bash
mkdir -p ~/.venvs
python3 -m venv ~/.venvs/kubespray
source ~/.venvs/kubespray/bin/activate
python -m pip install --upgrade pip
python -m pip install -r kubespray/upstream/requirements.txt
```

Die Datei `.envrc` im Repository setzt die Kubespray-Pfade und die
Ansible Umgebung. Bei Verwendung von `direnv` im
Repository-Stammverzeichnis ausführen:

``` bash
direnv allow
```

Erwartete Struktur der eigenen Konfiguration:

``` text
inventory/kubespray/
├── hosts.ini
├── group_vars/
│   └── k8s_cluster/
│       ├── k8s-cluster.yml
│       └── k8s-net-cilium.yml
└── credentials/
    └── kubeadm_certificate_key.creds  # lokales Geheimnis, nicht committen
```

Das Inventory definiert die drei Knoten, den SSH-Zugang (`core`) und die
Kubernetes-Gruppen `kube_control_plane`, `kube_node`, `etcd` und
`k8s_cluster`. Die Variablen unter `group_vars` legen
Kubernetes-Version, Container-Runtime, Netzwerkbereiche und
Cilium-Konfiguration fest.

## 3. Vor der Bereitstellung prüfen

Die folgenden Befehle im Stammverzeichnis von `hth-ansible-wks`
ausführen, während die virtuelle Umgebung aktiv ist:

``` bash
ansible --version
ansible-inventory -i "$KUBESPRAY_INVENTORY" --graph
ansible -i "$KUBESPRAY_INVENTORY" all -m ping
ansible-playbook -i "$KUBESPRAY_INVENTORY" "$KUBESPRAY_DIR/cluster.yml" --syntax-check
ansible-playbook -i "$KUBESPRAY_INVENTORY" "$KUBESPRAY_DIR/cluster.yml" --list-hosts
```

Fehler bei Inventory, SSH-Verbindungen oder Syntax vor dem vollständigen
Playbook-Lauf beheben.

## 4. Cluster aufbauen

``` bash
ansible-playbook -i "$KUBESPRAY_INVENTORY" "$KUBESPRAY_DIR/cluster.yml" -b -v
```

Kubespray installiert und konfiguriert Kubernetes, containerd, etcd,
CoreDNS und das ausgewählte CNI. In dieser Umgebung läuft etcd als
systemd-Dienst auf `coreos-master1`. Deshalb erscheint etcd nicht in der
Ausgabe von `kubectl get pods -A`. Auf den Workern stellt `nginx-proxy`
die Verbindung zum Kubernetes-API-Server bereit. Dieser Proxy ist kein
Ingress-Controller für Anwendungen wie Traefik.

## 5. Clusterzustand prüfen

Auf einem Rechner mit funktionierendem kubeconfig ausführen:

``` bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl -n kube-system get pods -o wide
kubectl get ciliumendpoints -A
```

Erwartetes Ergebnis: Alle drei Knoten stehen auf `Ready`; Cilium, Cilium
Operator, CoreDNS und die aktivierten Hubble-Komponenten laufen.

etcd auf dem Control-Plane-Knoten prüfen:

``` bash
sudo systemctl status etcd
sudo etcdctl member list -w table
```

Wenn `etcdctl` explizite TLS-Parameter benötigt, die tatsächliche
Dienstkonfiguration und die Zertifikatpfade prüfen, statt feste
Dateinamen anzunehmen:

``` bash
sudo systemctl cat etcd
sudo ls -la /etc/ssl/etcd/ssl/
```

## 6. Kubespray aktualisieren

Änderungen im Upstream vor einem Update prüfen. Eine neuere
Kubespray-Version kann Standardwerte oder Kompatibilitäten ändern.

``` bash
cd kubespray/upstream
git status
git switch master
git pull --ff-only
cd ../..

git add kubespray/upstream
git commit -m "Update Kubespray submodule"
git push
```

Das Haupt Repository speichert den ausgewählten Kubespray Commit. Vor
einem erneuten Playbook Lauf die Kompatibilität mit Fedora CoreOS,
Kubernetes und der Cilium-Konfiguration prüfen.

Bei einem frischen Klon stellt `git submodule update --init --recursive`
genau den Commit wieder her, auf den das Haupt-Repository verweist.

## 7. Cluster zurücksetzen

**Achtung: Dieser Schritt ist destruktiv.** Das Reset Playbook entfernt
Kubernetes Clusterkomponenten von den Hosts des Inventories. Nur
ausführen, wenn das Labor bewusst zurückgesetzt werden soll:

``` bash
ansible-playbook -i "$KUBESPRAY_INVENTORY" "$KUBESPRAY_DIR/reset.yml" -b -v
```

Anschließend kann das Cluster mit dem Playbook `cluster.yml` erneut
aufgebaut werden.

## Verwandte Repositories

-   [hth-kubernetes](https://github.com/hth73/hth-kubernetes) ---
    Kubernetes-Anwendungen und Manifeste.
-   [hth-ansible-wks](https://github.com/hth73/hth-ansible-wks) ---
    Ansible-Setup, Inventory und Kubespray-Integration.
-   [Kubespray Upstream](https://github.com/kubernetes-sigs/kubespray)
    --- Automatisierung der Kubernetes-Clusterbereitstellung.
