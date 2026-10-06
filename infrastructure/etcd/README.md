# etcd - reliable key-value store

<img src="https://img.shields.io/badge/etcd-419EDA?style=flat&logo=etcd&labelColor=ffffff&logoColor=419EDA" /> <img src="https://img.shields.io/badge/etcdctl-419EDA?style=flat&logo=etcd&labelColor=ffffff&logoColor=419EDA" /> <img src="https://img.shields.io/badge/etcdutl-419EDA?style=flat&logo=etcd&labelColor=ffffff&logoColor=419EDA" />

---

## Beschreibung

`etcd` ist ein verteilter, fehlertoleranter Key-Value-Store (Schlüssel-Werte-Speicher), der in Kubernetes als primärer Datenspeicher für den gesamten Cluster-Zustand dient.

In dieser Demo-Umgebung wurde der Service mit dem k3s Parameter `--cluster-init` als Embedded-etcd installiert.

## etcdctl und etcdutl Utility installieren

Um mit dem etcd Key-Value-Store arbeiten zu können, wurden hier die beiden Tools `etcdctl` und `etcdutl` installiert.

Die verwendete Tool-Version ist 3.7.2. Der K3s-Cluster verwendet eine kompatible etcd-Version aus dem 3.6.x-Zweig.

```bash
cd /tmp
wget https://github.com/etcd-io/etcd/releases/download/v3.7.2/etcd-v3.7.2-linux-amd64.tar.gz
tar -xvf etcd-v3.7.2-linux-amd64.tar.gz
cp /tmp/etcd-v3.7.2-linux-amd64/etcdctl /tmp/etcd-v3.7.2-linux-amd64/etcdutl ~/bin/
```

Für den Zugriff auf den etcd Key-Value-Store werden noch die passenden CA- und Client-Zertifikate benötigt.

```bash
ssh core@192.168.56.10 'sudo cat /var/lib/rancher/k3s/server/tls/etcd/server-ca.crt' > "$HOME/.kube/master1-server-ca.crt"
ssh core@192.168.56.10 'sudo cat /var/lib/rancher/k3s/server/tls/etcd/client.crt' > "$HOME/.kube/master1-client.crt"
ssh core@192.168.56.10 'sudo cat /var/lib/rancher/k3s/server/tls/etcd/client.key' > "$HOME/.kube/master1-client.key"

chmod 600 "$HOME/.kube/master1-client.key"
chmod 644 "$HOME/.kube/master1-server-ca.crt"
chmod 644 "$HOME/.kube/master1-client.crt"
```

Um nicht bei jedem Befehl die Endpoints und Zertifikate mitgeben zu müssen, wurden entsprechende Umgebungsvariablen in `~/.zshrc` angelegt.

```bash
vi ~/.zshrc

# Alle drei Endpoints für Cluster-weite Operationen
export ETCDCTL_ENDPOINTS="https://192.168.56.10:2379,https://192.168.56.11:2379,https://192.168.56.12:2379"
export ETCDCTL_CACERT="$HOME/.kube/master1-server-ca.crt"
export ETCDCTL_CERT="$HOME/.kube/master1-client.crt"
export ETCDCTL_KEY="$HOME/.kube/master1-client.key"

source ~/.zshrc
```

**Hinweis:** Für `etcdctl snapshot save` muss ein einzelner Endpoint verwendet werden. Daher wird vor dem Erstellen eines Snapshots die Variable `ETCDCTL_ENDPOINTS` auf einen einzelnen Endpoint gesetzt.

Die passende etcd Service-Konfiguration findet man auf den Master-Servern unter folgendem Pfad:

```bash
ssh core@192.168.56.10 -p 22

sudo cat /var/lib/rancher/k3s/server/db/etcd/config

# advertise-client-urls: https://192.168.56.10:2379
# client-transport-security:
#   cert-file: /var/lib/rancher/k3s/server/tls/etcd/server-client.crt
#   client-cert-auth: true
#   key-file: /var/lib/rancher/k3s/server/tls/etcd/server-client.key
#   trusted-ca-file: /var/lib/rancher/k3s/server/tls/etcd/server-ca.crt
# data-dir: /var/lib/rancher/k3s/server/db/etcd
# election-timeout: 5000
# experimental-initial-corrupt-check: true
# experimental-watch-progress-notify-interval: 5000000000
# heartbeat-interval: 500
# listen-client-http-urls: https://127.0.0.1:2382
# listen-client-urls: https://127.0.0.1:2379,https://192.168.56.10:2379
# listen-metrics-urls: http://127.0.0.1:2381
# listen-peer-urls: https://127.0.0.1:2380,https://192.168.56.10:2380
# log-outputs:
# - stderr
# logger: zap
# name: coreos-master1-933c287a
# peer-transport-security:
#   cert-file: /var/lib/rancher/k3s/server/tls/etcd/peer-server-client.crt
#   client-cert-auth: true
#   key-file: /var/lib/rancher/k3s/server/tls/etcd/peer-server-client.key
#   trusted-ca-file: /var/lib/rancher/k3s/server/tls/etcd/peer-ca.crt
# snapshot-count: 10000
# socket-options:
#   reuse-address: true
#   reuse-port: true
```

### Cluster Mitglieder anzeigen

```bash
etcdctl member list -w table
# ┌──────────────────┬─────────┬─────────────────────────┬────────────────────────────┬────────────────────────────┬────────────┐
# │        ID        │ STATUS  │          NAME           │         PEER ADDRS         │        CLIENT ADDRS        │ IS LEARNER │
# ├──────────────────┼─────────┼─────────────────────────┼────────────────────────────┼────────────────────────────┼────────────┤
# │ 4a66cfb2886891bd │ started │ coreos-master2-186aaa5f │ https://192.168.56.11:2380 │ https://192.168.56.11:2379 │      false │
# │ bd23ee18c34e31cc │ started │ coreos-master3-3243018a │ https://192.168.56.12:2380 │ https://192.168.56.12:2379 │      false │
# │ f0e4577804b51494 │ started │ coreos-master1-933c287a │ https://192.168.56.10:2380 │ https://192.168.56.10:2379 │      false │
# └──────────────────┴─────────┴─────────────────────────┴────────────────────────────┴────────────────────────────┴────────────┘
```

### Cluster Status abfragen

```bash
# Tabelle wurde gekürzt
# etcdctl endpoint status -w table
etcdctl endpoint status --write-out=table

ENDPOINT             │   ID  │ VERSION │ STORAGE VER │ DB SIZE │ IN USE │ NOT IN USE │ QUOTA  │ LEADER │ LEARNER │ RAFT TERM │ RAFT INDEX │ RAFT APPLIED INDEX │ DOWNGRADE ENABLED
─────────────────────┼───────┼─────────┼─────────────┼─────────┼────────┼────────────┼────────┼────────┼─────────┼───────────┼────────────┼────────────────────┼───────────────────
https://192.xxx:2379 │ f0804 │  3.6.14 │       3.6.0 │   22 MB │ 8.8 MB │        61% │ 2.1 GB │   true │   false │         2 │      26548 │              26548 │             false
https://192.xxx:2379 │ 4a288 │  3.6.14 │       3.6.0 │   19 MB │ 8.7 MB │        54% │ 2.1 GB │  false │   false │         2 │      26548 │              26548 │             false
https://192.xxx:2379 │ bd8c3 │  3.6.14 │       3.6.0 │   19 MB │ 8.7 MB │        54% │ 2.1 GB │  false │   false │         2 │      26548 │              26548 │             false


etcdctl endpoint status --write-out=fields
# "ClusterID" : 2110508821268288304
# "MemberID" : 17358095036779402388
# "Revision" : 89559
# "RaftTerm" : 5
# "Version" : "3.6.14"
# "StorageVersion" : "3.6.0"
# "DBSize" : 13352960
# "DBSizeInUse" : 8122368
# "DBSizeQuota" : 2147483648
# "Leader" : 17358095036779402388
# "IsLearner" : false
# "RaftIndex" : 111350
# "RaftAppliedIndex" : 111350
# "Errors" : []
# "Endpoint" : "https://192.168.56.10:2379"
# "DowngradeTargetVersion" : ""
# "DowngradeEnabled" : false
```

### Health Check

```bash
etcdctl endpoint health -w table
# ┌────────────────────────────┬────────┬────────────┬───────┐
# │          ENDPOINT          │ HEALTH │    TOOK    │ ERROR │
# ├────────────────────────────┼────────┼────────────┼───────┤
# │ https://192.168.56.10:2379 │   true │ 6.061662ms │       │
# │ https://192.168.56.11:2379 │   true │ 6.396156ms │       │
# │ https://192.168.56.12:2379 │   true │ 6.938156ms │       │
# └────────────────────────────┴────────┴────────────┴───────┘
```

### Datenbank Snapshot erstellen und Status ansehen

Für einen Snapshot muss gezielt ein einzelner etcd-Endpoint verwendet werden.

```bash
export ETCDCTL_ENDPOINTS="https://192.168.56.10:2379"
etcdctl snapshot save "$HOME/.kube/etcd-snapshot.db"

etcdutl snapshot status "$HOME/.kube/etcd-snapshot.db" -w table
# ┌──────────┬──────────┬────────────┬────────────┬─────────┐
# │   HASH   │ REVISION │ TOTAL KEYS │ TOTAL SIZE │ VERSION │
# ├──────────┼──────────┼────────────┼────────────┼─────────┤
# │ 52d287af │    76042 │        606 │      13 MB │   3.6.0 │
# └──────────┴──────────┴────────────┴────────────┴─────────┘
```

### Hash-Wert vom Key-Value-Store (MVCC-Historie) ausgeben lassen

Der Hash-Wert kann verwendet werden, um den logischen KV-Datenbestand verschiedener etcd-Mitglieder auf Konsistenz zu prüfen.

```bash
# Online
etcdctl endpoint hashkv --cluster -w table
# ┌────────────────────────────┬──────────┬───────────────┐
# │          ENDPOINT          │   HASH   │ HASH REVISION │
# ├────────────────────────────┼──────────┼───────────────┤
# │ https://192.168.56.11:2379 │ 83008731 │        168288 │
# │ https://192.168.56.12:2379 │ 83008731 │        168288 │
# │ https://192.168.56.10:2379 │ 83008731 │        168288 │
# └────────────────────────────┴──────────┴───────────────┘

# Offline
etcdutl hashkv --write-out=table "$HOME/.kube/etcd-snapshot.db"
# ┌──────────┬───────────────┬──────────────────┐
# │   HASH   │ HASH REVISION │ COMPACT REVISION │
# ├──────────┼───────────────┼──────────────────┤
# │ 80864178 │         83220 │            80489 │
# └──────────┴───────────────┴──────────────────┘
```

### Key-Values anzeigen

```bash
etcdctl get "" --prefix --keys-only | less
# /bootstrap/24188149fe43
# /registry/apiextensions.k8s.io/customresourcedefinitions/accesscontrolpolicies.hub.traefik.io
# /registry/apiextensions.k8s.io/customresourcedefinitions/addons.k3s.cattle.io
# /registry/apiextensions.k8s.io/customresourcedefinitions/aiservices.hub.traefik.io
# /registry/apiextensions.k8s.io/customresourcedefinitions/apiauths.hub.traefik.io

etcdctl get "/registry" --prefix --keys-only | less
etcdctl get "/registry/nodes" --prefix --keys-only
etcdctl get "/registry/nodes/coreos-master1" --print-value-only
etcdctl get "/registry/nodes/coreos-master1" --print-value-only --write-out simple

# k8s
# v1Node�/
#
# �
# coreos-master1�"* $26712d87-42c3-4aa1-a514-4cb933420ff72�ߏ�Z
# beta.kubernetes.io/archamd64Z'
# beta.kubernetes.io/instance-typek3sZ
# ...
# 192.168.56.10b!coreos.com/public-ip
# k3s.io/hostnamecoreos-master1b#
# 192.168.56.10b�-ip
# k3s.io/node-argsn["server","--cluster-init","--node-ip","192.168.56.10","--flannel-iface","enp0s8","--tls-san","192.168.56.10"]bS
```

### Alte Revisionen löschen

Der Befehl `etcdctl compact` entfernt alte historische Revisionen aus dem etcd Key-Value-Store.

```text
Also vereinfacht:

  Revision 1
  Revision 2
  Revision 3
  ...
  Revision 169631
             ↑
          compact
```

Historische Versionen vor der Compaction werden danach nicht mehr verfügbar sein.

```bash
rev=$(etcdctl endpoint status --write-out=fields | awk -F': ' '/Revision/{print $2; exit}')
echo "$rev"
# 169631

etcdctl compact "$rev"
```

### etcd Datenbank verkleinern

Der Befehl `etcdctl defrag` reorganisiert den physischen etcd-Backend-Speicher und gibt nicht mehr benötigten bzw. fragmentierten Speicherplatz innerhalb der Datenbank wieder frei.

Die Defragmentierung ist von der MVCC-Compaction zu unterscheiden.

```bash
etcdctl defrag
```

### kubeadm-Cluster mit Static-Pod-etcd

Bei einem kubeadm-Cluster wird etcd typischerweise als Static Pod betrieben.

```bash
cat /etc/kubernetes/manifests/etcd.yaml
```

`--auto-compaction-retention` legt fest, wie viel Historie behalten wird.
`--auto-compaction-mode` legt fest, nach welcher Zeit (`periodic`) oder nach welcher Anzahl von Revisionen (`revision`) die automatische Compaction erfolgt.

In etcd 3.6 ist `auto-compaction-retention=0` standardmäßig deaktiviert.

```bash
# Hier behält etcd ungefähr die letzten 1000 Revisionen
--auto-compaction-retention=1000
--auto-compaction-mode=revision

# Zeitgesteuerte automatische Compaction
# Beispiele für gültige Zeitwerte:
# 30m, 1h, 10h, 24h, 72h

--auto-compaction-mode=periodic
--auto-compaction-retention=24h
```
