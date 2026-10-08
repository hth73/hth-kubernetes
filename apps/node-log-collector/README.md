# Node Log Collector - DaemonSet

Dieses Beispiel zeigt die Verwendung eines Kubernetes `DaemonSet`, um auf jedem passenden Node einen Pod bereitzustellen, der die lokalen
Container-Logs des Nodes ausliest.

---

[Back to home](../../README.md)

---

## 1. Warum ein DaemonSet?

Ein `Deployment` definiert eine Anzahl von Pods:

```yaml
replicas: 3
```

Ein `DaemonSet` stellt dagegen sicher, dass auf jedem passenden Node
ein Pod läuft.

```text
                 DaemonSet
                     │
        ┌────────────┼────────────┐
        ▼            ▼            ▼
     master1      worker1      worker2
       Pod          Pod          Pod
```

Wird ein neuer passender Node hinzugefügt, erstellt Kubernetes dort
automatisch einen neuen Pod.

Wird ein DaemonSet-Pod gelöscht, wird er automatisch ersetzt.

---

## 2. DaemonSet

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-log-collector
  namespace: kube-system

spec:
  selector:
    matchLabels:
      app: node-log-collector

  template:
    metadata:
      labels:
        app: node-log-collector

    spec:
      containers:
        - name: log-collector
          image: busybox:1.36

          command:
            - sh
            - -c
            - |
              echo "Node Log Collector started"
              echo "Node: ${NODE_NAME}"
              tail -F /var/log/containers/*.log

          env:
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName

          volumeMounts:
            - name: container-logs
              mountPath: /var/log/containers
              readOnly: true

            - name: pod-logs
              mountPath: /var/log/pods
              readOnly: true

      volumes:
        - name: container-logs
          hostPath:
            path: /var/log/containers
            type: Directory

        - name: pod-logs
          hostPath:
            path: /var/log/pods
            type: Directory
```

---

## 3. Warum zwei Log-Verzeichnisse?

Unter:

```text
/var/log/containers
```

befinden sich Container-Logdateien bzw. Symlinks.

Diese verweisen auf die eigentlichen Logdateien unter:

```text
/var/log/pods
```

Vereinfacht:

```text
/var/log/containers/*.log
          │
          │ Symlink
          ▼
/var/log/pods/...
          │
          ▼
      Logdatei
```

Deshalb müssen beide Verzeichnisse als `hostPath` eingebunden werden.

---

## 4. Warum `hostPath`?

Die Logs befinden sich auf dem jeweiligen Kubernetes Node.

Mit:

```yaml
hostPath:
  path: /var/log/containers
```

wird das Verzeichnis des Nodes in den Pod eingebunden.

Da der Collector die Dateien nur lesen soll:

```yaml
readOnly: true
```

verwenden.

`hostPath` sollte generell bewusst eingesetzt werden, da der Pod dadurch
Zugriff auf das Dateisystem des Nodes erhält.

---

## 5. Node-Name über Downward API

Der Node-Name wird automatisch über die Kubernetes Downward API bereitgestellt:

```yaml
env:
  - name: NODE_NAME
    valueFrom:
      fieldRef:
        fieldPath: spec.nodeName
```

Dadurch kann der Collector beispielsweise ausgeben:

```text
Node Log Collector started
Node: coreos-worker1
```

---

## 6. Container Log Rotation

Die Container-Logs werden vom Kubelet verwaltet.

Die Kubernetes-Defaults sind:

```text
containerLogMaxSize  = 10Mi
containerLogMaxFiles = 5
```

Die Logrotation verhindert dadurch, dass die Container-Logs unbegrenzt
wachsen.

Die Logrotation ist unabhängig von der Disk-Eviction des Kubelets.

Beispiel:

```yaml
evictionHard:
  nodefs.available: 5%
```

Damit existieren zwei unterschiedliche Schutzmechanismen:

```text
Container Logs
      │
      ├── Logrotation
      │     ├── 10 MiB
      │     └── 5 Dateien
      │
      └── Disk Eviction
            └── nodefs.available < 5%
```

Der Log-Collector selbst übernimmt **keine Logrotation**.

---

## 7. DaemonSet überprüfen

DaemonSets anzeigen:

```bash
kubectl get daemonsets -A
```

Pods anzeigen:

```bash
kubectl get pods -n kube-system \
  -l app=node-log-collector \
  -o wide
```

Logs eines Collectors anzeigen:

```bash
kubectl logs -n kube-system <pod-name>
```

---

## 8. Wichtige CKA-Punkte

Dieses Beispiel verbindet mehrere wichtige Kubernetes-Konzepte:

- `DaemonSet` → ein Pod pro passendem Node
- `hostPath` → Zugriff auf Node-Dateisystem
- `volumeMounts`
- `readOnly`
- `Downward API`
- Node Selector / Affinity
- Taints / Tolerations
- Container Logs
- Kubelet Log Rotation

### Merksatz

> **DaemonSet = Ein Pod pro passendem Node.**

Für einen Node-basierten Log-Collector ist ein DaemonSet daher das
passende Kubernetes-Workload-Objekt.
