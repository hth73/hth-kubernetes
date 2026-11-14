# Kubernetes Clusters from Scratch with kubeone

## 1. Architektur und Versionsstand

  Komponente           Bisheriger Stand
  -------------------- --------------------------------------------------
  Provisionierung      Vagrant / VirtualBox
  Betriebssystem       Flatcar Container Linux
  Cluster-Management   KubeOne `v1.15.0`
  Kubernetes           `v1.37.2`
  Container Runtime    containerd `2.2.5`
  CNI                  Cilium `1.20.2`
  kube-proxy           Nicht installiert; Cilium übernimmt die Funktion
  Routing-Ziel         Native Routing
  Verschlüsselung      WireGuard
  Hubble               Aktiviert, inklusive Relay und UI
  Pod-Netz             `172.20.0.0/16`
  Service-Netz         `10.96.0.0/12`
  Host-only-Netz       `192.168.56.0/24`, Interface `enp0s8`

### Nodes

  Node                Rolle                Host-only-IP    RAM   CPUs
  ------------------- --------------- ----------------- ------ ------
  `flatcar-master1`   Control Plane     `192.168.56.10`   8 GB      2
  `flatcar-worker1`   Worker            `192.168.56.13`   4 GB      2
  `flatcar-worker2`   Worker            `192.168.56.14`   4 GB      2

Die Nodes besitzen zusätzlich eine NAT-Schnittstelle (`enp0s3`). Für
Cilium wurde `enp0s8` als Netzwerkinterface vorgesehen.

## 2. Repository- und Addon-Struktur

KubeOne-Projekt im Repository `hth-ansible-wks`:

``` text
hth-ansible-wks/
└── kubeone/
    ├── kubeone.yaml
    └── addons/
        └── cni-cilium/
            ├── cilium-config-map.yaml
            ├── cilium.yaml
            ├── helm-values
            ├── hubble.yaml
            ├── Kustomization
            ├── Makefile
            ├── poddisruptionbudgets.yaml
            └── README.md
```

Das Cilium-Addon ist ein lokales Override des in KubeOne `v1.15.0`
eingebetteten Addons `cni-cilium`. KubeOne meldete es mit
`kubeone addons list` als `overridden`.

**Wichtig:** Cilium wird in dieser Architektur nicht als eigenständiges
Helm-Release verwaltet. `helm list -A` war leer. Die lokale
Addon-Struktur wird von KubeOne verarbeitet. Daher nicht mit
`helm upgrade` oder einem direkten `kubectl apply -f cilium.yaml`
aktualisieren.

## 3. KubeOne-Manifest

Bisher verwendeter relevanter Ausschnitt aus `kubeone/kubeone.yaml`:

``` yaml
clusterNetwork:
  podSubnet: 172.20.0.0/16
  serviceSubnet: 10.96.0.0/12
  cni:
    cilium:
      kubeProxyReplacement: strict
      enableHubble: true
  kubeProxy:
    skipInstallation: true
```

Bedeutung:

-   `podSubnet`: clusterweiter Pod-IP-Adressbereich.
-   `serviceSubnet`: Kubernetes-Service-IP-Adressbereich.
-   `kubeProxyReplacement: strict`: Cilium übernimmt die
    kube-proxy-Funktion.
-   `enableHubble: true`: Hubble-Unterstützung wird über die
    KubeOne-Cilium-Integration aktiviert.
-   `skipInstallation: true`: KubeOne installiert keinen kube-proxy.

Die obige Konfiguration ist der bekannte relevante Ausschnitt. Weitere
Felder des vollständigen Manifests (z. B. API-Endpoint, Hosts,
SSH-Konfiguration und Versionsdefinition) sind hier absichtlich nicht
ergänzt, da sie in dieser Referenz nicht vollständig dokumentiert sind.
Für einen Neuaufbau die vorhandene vollständige Datei als Ausgangspunkt
verwenden und vor Änderungen prüfen.

## 4. Cilium-Konfiguration

Die gewünschte Cilium-Konfiguration wurde aus dem bisherigen
Helm-Values-Ansatz abgeleitet und in das KubeOne-Addon übertragen.

### Zielwerte

``` yaml
cluster:
  name: kubernetes

devices:
  - enp0s8

ipam:
  mode: cluster-pool
  operator:
    clusterPoolIPv4PodCIDRList:
      - "172.20.0.0/16"
    clusterPoolIPv4MaskSize: 24

kubeProxyReplacement: true

routingMode: native
ipv4NativeRoutingCIDR: "172.20.0.0/16"
autoDirectNodeRoutes: true

encryption:
  enabled: true
  type: wireguard

cni:
  exclusive: false

preflight:
  enabled: false

l2announcements:
  enabled: true

operator:
  enabled: true
  replicas: 1
  podDisruptionBudget:
    enabled: true

# Hubble wird durch KubeOnes Addon-Ressourcen verwaltet.
serviceAccounts:
  hubblecertgen:
    create: false
  relay:
    create: false
  ui:
    create: false

hubble:
  enabled: false
  relay:
    enabled: false
  tls:
    enabled: false
    auto:
      enabled: false
      method: cronJob
  ui:
    enabled: false
```

**Hinweis zum Hubble-Setup:** Die obigen Values deaktivieren die
Hubble-Komponenten im Cilium-Helm-Chart, weil Hubble-Ressourcen separat
über `hubble.yaml` durch das KubeOne-Addon verwaltet werden. Hubble,
Relay und UI waren im laufenden Cluster vorhanden.

### KubeOne-Cilium-ConfigMap

Die lokale Datei `cilium-config-map.yaml` enthält unter anderem diese
relevanten Einstellungen:

``` yaml
auto-direct-node-routes: "true"
cluster-name: kubernetes
devices: "enp0s8"
routing-mode: native
enable-wireguard: "true"
ipv4-native-routing-cidr: "172.20.0.0/16"
ipam: cluster-pool
```

Außerdem bleiben die KubeOne-Templates für die Hubble- und
kube-proxy-Einstellungen erhalten. Die Kubernetes-API-Adresse wird über
KubeOne-Templates gesetzt:

``` yaml
KUBERNETES_SERVICE_HOST: "{{ .Config.APIEndpoint.Host }}"
KUBERNETES_SERVICE_PORT: "{{ .Config.APIEndpoint.Port }}"
```

**Nicht zusätzlich in `helm-values` setzen:** `k8sServiceHost` und
`k8sServicePort`. KubeOne patcht die entsprechenden Umgebungsvariablen
über `valueFrom`-Referenzen auf die `cilium-config`-ConfigMap. Eine
zusätzliche `value`-Angabe kann zu einem ungültigen Env-Eintrag führen,
der gleichzeitig `value` und `valueFrom` enthält.

In der ConfigMap-Datei war nach der Umstellung noch
`tunnel-source-port-range: 0-0` vorhanden. Das ist ein verbliebener
Tunnel-Parameter; für Native Routing ist entscheidend, dass
`routing-mode: native` gesetzt ist und kein aktives
VXLAN-Tunnel-Protokoll mehr konfiguriert wird. Beim Neuaufbau die Datei
konsistent bereinigen und anhand der Cilium-1.20.2-Werte validieren.

## 5. Addon rendern und prüfen

Im Verzeichnis des lokalen Addons:

``` bash
cd kubeone/addons/cni-cilium
```

Cilium-Manifeste mit Kustomize und Helm-Integration rendern:

``` bash
kubectl kustomize --enable-helm --helm-command=helm . > cilium.yaml
```

Die erzeugte Datei ist ein gerendertes Artefakt des Addons. Sie wird
nicht direkt mit `kubectl apply` ausgerollt, sondern von KubeOne
verarbeitet.

Prüfen, ob die gerenderten Env-Einträge gleichzeitig `value` und
`valueFrom` enthalten. Mit `yq` aus dem Python-Paket `kislyuk/yq`
(jq-Wrapper) wurde folgende Prüfung verwendet:

``` bash
yq -s '[ .[] | .. | objects | select(has("value") and has("valueFrom")) ] | length' cilium.yaml
```

Erwartetes Ergebnis:

``` text
0
```

Diese Prüfung kontrolliert ausschließlich das Vorhandensein beider
Felder im gerenderten YAML. Sie validiert nicht die vollständige
Cilium-Laufzeitkonfiguration.

Addon-Status über KubeOne anzeigen:

``` bash
kubeone addons list --manifest kubeone/kubeone.yaml
```

Für das lokale Override wurde angezeigt:

``` text
cni-cilium    install    overridden
```

## 6. Cluster anwenden

Im Repository-Root:

``` bash
kubeone apply --manifest kubeone/kubeone.yaml --debug
```

`--force-upgrade` war für den normalen Apply nicht erforderlich. KubeOne
gab beim gleichen Kubernetes-Versionsstand eine Warnung aus, dass die
gewünschte Version der aktuellen Version entspricht. Das war nicht der
eigentliche Fehler.

### Besonderheit: fehlende kube-proxy-ConfigMap

Da `kubeProxy.skipInstallation: true` gesetzt ist, existierten im
Cluster zunächst weder die ConfigMap `kube-proxy` noch ein
kube-proxy-DaemonSet.

KubeOne `v1.15.0` versucht beim Aktualisieren der kubeadm-ConfigMaps
dennoch, die ConfigMap `kube-proxy` zu aktualisieren. Im untersuchten
Quellcode wird diese ConfigMap ohne Prüfung auf `skipInstallation` in
die Update-Liste aufgenommen. Dadurch scheiterte der Apply mit:

``` text
updating kube-proxy ConfigMap: configmaps "kube-proxy" not found
```

Als Workaround wurde eine leere ConfigMap angelegt:

``` bash
kubectl create configmap kube-proxy --namespace kube-system --from-literal=config.conf='{}'
```

Prüfen:

``` bash
kubectl -n kube-system get cm kube-proxy -o yaml
kubectl -n kube-system get ds kube-proxy
```

Erwartung: ConfigMap vorhanden, kube-proxy-DaemonSet weiterhin nicht
vorhanden.

Danach konnte der KubeOne-Apply erneut ausgeführt werden. KubeOne
evakuierte dabei den Control-Plane-Node (cordon/drain), der
Cilium-Operator wurde neu erstellt und die Pods kamen anschließend
wieder in den Zustand `Running`.

**Einordnung:** Das ist ein dokumentierter Workaround für das
beobachtete Verhalten von KubeOne `v1.15.0`, keine allgemeine
Kubernetes-Anforderung. Vor einem späteren KubeOne-Upgrade prüfen, ob
das Verhalten korrigiert wurde. `skipInstallation` nicht nur zur
Umgehung des Fehlers deaktivieren, da dies kube-proxy installieren
könnte.

## 7. Zustand nach dem Apply prüfen

### Nodes

``` bash
kubectl get nodes -o wide
```

Alle drei Nodes müssen `Ready` sein.

### System-Pods

``` bash
kubectl -n kube-system get pods -o wide
```

Im bisherigen erfolgreichen Zustand liefen unter anderem:

-   3 Cilium-Agenten (je ein Pod pro Node)
-   3 Cilium-Envoy-Pods (je ein Pod pro Node)
-   1 Cilium-Operator
-   2 CoreDNS-Pods
-   Hubble Relay
-   Hubble UI
-   3 NodeLocal-DNS-Pods (je ein Pod pro Node)
-   metrics-server
-   Control-Plane-Static-Pods und etcd

### Cilium-ConfigMap

``` bash
kubectl -n kube-system get cm cilium-config -o yaml
```

Relevante Werte kontrollieren:

``` bash
kubectl -n kube-system get cm cilium-config -o yaml |
  grep -E 'routing-mode|ipv4-native-routing-cidr|auto-direct-node-routes|enable-wireguard|devices|cluster-pool'
```

Erwartete Zielwerte:

-   `routing-mode: native`
-   `ipv4-native-routing-cidr: 172.20.0.0/16`
-   `auto-direct-node-routes: true`
-   `enable-wireguard: true`
-   `devices: enp0s8`
-   IPAM `cluster-pool`

### Cilium-Status

``` bash
kubectl -n kube-system exec ds/cilium -- cilium-dbg status
```

Bei Bedarf ausführlicher:

``` bash
kubectl -n kube-system exec ds/cilium -- cilium-dbg status --verbose
```

### kube-proxy-Abwesenheit prüfen

``` bash
kubectl -n kube-system get ds kube-proxy
kubectl -n kube-system get cm kube-proxy
```

Die erste Abfrage soll `NotFound` melden; die ConfigMap darf als
KubeOne-Workaround vorhanden sein.

### WireGuard-Kernelmodul

Das WireGuard-Modul wurde auf allen drei Flatcar-Nodes erfolgreich
geladen. Auf jedem Node prüfen:

``` bash
lsmod | grep wireguard
```

WireGuard-Status auf dem Host:

``` bash
sudo wg show
```

## 8. Wichtige offene Punkte für den vollständigen Neuaufbau

### 8.1 Feste Pod-CIDRs pro Node

Das bisher konfigurierte Cilium-IPAM verwendet:

``` yaml
ipam:
  mode: cluster-pool
  operator:
    clusterPoolIPv4PodCIDRList:
      - "172.20.0.0/16"
    clusterPoolIPv4MaskSize: 24
```

Damit wird ein Pool aus `/24`-Netzen definiert. Es wurde **keine feste
Zuordnung** der einzelnen `/24`-Netze zu den Nodes konfiguriert.

Die zuletzt beobachtete dynamische Zuweisung war:

-   `flatcar-master1`: `172.20.0.0/24` (CoreDNS-Pod z. B. `172.20.0.17`)
-   `flatcar-worker1`: `172.20.1.0/24` (CoreDNS-Pod z. B.
    `172.20.1.120`)
-   `flatcar-worker2`: tatsächliche Zuweisung noch zu prüfen

Gewünschte Zuordnung für den nächsten Aufbau:

  Node                Gewünschtes Pod-CIDR
  ------------------- ----------------------
  `flatcar-master1`   `172.20.10.0/24`
  `flatcar-worker1`   `172.20.13.0/24`
  `flatcar-worker2`   `172.20.14.0/24`

Diese Zuordnung ist ein **offener Designpunkt**. Vor dem Neuaufbau muss
geprüft werden, welche von Cilium 1.20.2 und KubeOne unterstützte
Methode die gewünschte deterministische Zuweisung ermöglicht. Nicht
einfach annehmen, dass `clusterPoolIPv4MaskSize: 24` die Zuordnung
anhand der Node-IP oder des Hostnamens vornimmt.

Prüfkommandos:

``` bash
kubectl get nodes \
  -o custom-columns=NAME:.metadata.name,PODCIDR:.spec.podCIDR,PODCIDRS:.spec.podCIDRs

kubectl get ciliumnodes \
  -o custom-columns=NAME:.metadata.name,PODCIDRS:.spec.ipam.podCIDRs
```

### 8.2 Native Routing und Host-Routen

Native Routing setzt voraus, dass die Node-Netze gegenseitig erreichbar
sind. Mit `autoDirectNodeRoutes: true` soll Cilium direkte Routen
zwischen den Nodes verwalten. Nach dem Aufbau prüfen:

``` bash
ip route
```

Auf jedem Node muss die Erreichbarkeit der Pod-CIDRs der anderen Nodes
gewährleistet sein. Das Host-only-Netz `192.168.56.0/24` und das
Interface `enp0s8` sind dabei relevant.

### 8.3 Funktionstests

Nach dem Neuaufbau mindestens prüfen:

-   Pod-zu-Pod-Kommunikation zwischen unterschiedlichen Nodes
-   DNS-Auflösung über CoreDNS
-   Service-Erreichbarkeit über ClusterIP
-   WireGuard-Peers und verschlüsselter Node-zu-Node-Verkehr
-   Hubble Relay und UI
-   Erreichbarkeit der Nodes über das Host-only-Netz

## 9. Kompakte Befehlsreferenz

Die Befehle im Repository-Root ausführen, sofern nicht anders angegeben.

``` bash
# KubeOne-Version
kubeone version

# Nodes
kubectl get nodes -o wide

# Alle System-Pods
kubectl -n kube-system get pods -o wide

# Lokale KubeOne-Addons anzeigen
kubeone addons list --manifest kubeone/kubeone.yaml

# In das lokale Cilium-Addon wechseln
cd kubeone/addons/cni-cilium

# Cilium-Manifeste rendern
kubectl kustomize --enable-helm --helm-command=helm . > cilium.yaml

# Zurück ins Repository-Root
cd ../../..

# KubeOne-Änderungen anwenden
kubeone apply --manifest kubeone/kubeone.yaml --debug

# Cilium-Konfiguration prüfen
kubectl -n kube-system get cm cilium-config -o yaml

# Cilium-Status prüfen
kubectl -n kube-system exec ds/cilium -- cilium-dbg status --verbose

# Pod-CIDRs der Kubernetes-Nodes
kubectl get nodes \
  -o custom-columns=NAME:.metadata.name,PODCIDR:.spec.podCIDR,PODCIDRS:.spec.podCIDRs

# Pod-CIDRs der CiliumNodes
kubectl get ciliumnodes \
  -o custom-columns=NAME:.metadata.name,PODCIDRS:.spec.ipam.podCIDRs

# kube-proxy-DaemonSet darf nicht vorhanden sein
kubectl -n kube-system get ds kube-proxy

# kube-proxy-ConfigMap (KubeOne-Workaround) prüfen
kubectl -n kube-system get cm kube-proxy -o yaml
```

## 10. Status / Übergabe

### Bestätigt umgesetzt

-   KubeOne `v1.15.0` verwaltet den Kubernetes-Cluster.
-   Drei Flatcar-Nodes: ein Control Plane, zwei Worker.
-   Kubernetes `v1.37.2` und containerd `2.2.5`.
-   Cilium `1.20.2` als KubeOne-Addon; lokales Addon überschreibt das
    eingebettete Addon.
-   kube-proxy-Installation in KubeOne deaktiviert; Cilium kube-proxy
    replacement aktiviert.
-   Hubble, Relay und UI liefen.
-   Lokale Cilium-Addon-Dateien und Kustomize/Helm-Rendering
    eingerichtet.
-   WireGuard-Kernelmodul auf allen drei Nodes vorhanden.
-   KubeOne-Apply nach Anlegen der `kube-proxy`-ConfigMap erfolgreich
    durchgelaufen; System-Pods waren anschließend wieder `Running`.
