# Spring Petclinic Demo Application

<img src="https://img.shields.io/badge/petclinic-6DB33F?style=flat&logo=spring&labelColor=ffffff&logoColor=6DB33F" />

---

* [Github Spring Projekt Petclinic](https://github.com/spring-projects/spring-petclinic)
* [Spring Petclinic Community - Docker Image](https://hub.docker.com/u/springcommunity)

---

[Back to home](../../README.md)

---

## Beschreibung

In dieser praktischen Übung werden mehrere zentrale Kubernetes-Workload-Konzepte anhand der bestehenden **Spring Petclinic Demo Application** praktisch umgesetzt und miteinander verglichen.

Der Lernweg:

```text
Deployment
    │
    ├── Init Container
    │      └── wartet auf PostgreSQL
    │
    ├── Petclinic Container
    │      └── Spring Boot Application
    │
    └── Sidecar Container
           └── liest Application Logs
                  │
                  ▼
               emptyDir
```

Anschließend wird das Deployment durch ein **StatefulSet** ersetzt:

```text
StatefulSet
    │
    ├── petclinic-0 ─── data-petclinic-0
    ├── petclinic-1 ─── data-petclinic-1
    └── petclinic-2 ─── data-petclinic-2
```

Dabei werden insbesondere folgende Kubernetes-Konzepte praktisch untersucht:

- Deployment
- ReplicaSets
- RollingUpdate
- Init Container
- Sidecar Container
- gemeinsames `emptyDir`
- StatefulSet
- `serviceName`
- stabile Pod-Identität
- `volumeClaimTemplates`
- PersistentVolumeClaim (PVC)
- StorageClass
- PersistentVolume (PV)
- Unterschied zwischen Deployment und StatefulSet

---

# 1. Ausgangssituation

Als Anwendung wird die Spring Petclinic Demo Application verwendet.

Image:

```text
docker.io/springcommunity/spring-petclinic:3.5.6
```

Die Anwendung läuft auf Port:

```text
8080
```

Die Petclinic befindet sich im Namespace:

```text
petclinic
```

PostgreSQL befindet sich in einem separaten Namespace:

```text
postgresql
```

Die Anwendung wartet beim Start über einen Init Container auf PostgreSQL:

```text
forgejo-postgres-rw.postgresql.svc.cluster.local:5432
```

---

# 2. Deployment

Zunächst wird Petclinic als normales Kubernetes Deployment betrieben.

Grundlegende Struktur:

```text
Deployment
    │
    └── ReplicaSet
          │
          ├── Pod
          ├── Pod
          └── Pod
```

Beispiel:

```yaml
apiVersion: apps/v1
kind: Deployment

metadata:
  name: petclinic
  namespace: petclinic

spec:
  replicas: 3

  selector:
    matchLabels:
      app.kubernetes.io/name: petclinic

  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1

  template:
    metadata:
      labels:
        app.kubernetes.io/name: petclinic

    spec:
      containers:
        - name: petclinic
          image: docker.io/springcommunity/spring-petclinic:3.5.6
```

## Wichtige Punkte

Bei drei Replicas und:

```yaml
maxSurge: 1
maxUnavailable: 1
```

können während eines Rollouts maximal vier Pods existieren.

Gleichzeitig dürfen maximal zwei der gewünschten drei Replicas verfügbar sein.

```text
Desired Replicas:       3
Max Surge:             +1
Max Pods:                4

Max Unavailable:         1
Minimum Available:       2
```

---

# 3. Init Container

Die Petclinic-Anwendung benötigt PostgreSQL.

Daher wird ein Init Container verwendet, der vor dem eigentlichen Application Container ausgeführt wird.

```yaml
initContainers:
  - name: wait-for-postgresql
    image: busybox:1.36

    command:
      - sh
      - -c
      - |
        echo "Waiting for PostgreSQL..."

        until nc -z forgejo-postgres-rw.postgresql.svc.cluster.local 5432; do
          echo "PostgreSQL is not available yet..."
          sleep 2
        done

        echo "PostgreSQL is available!"
```

## Funktionsweise

```text
Pod startet
    │
    ▼
Init Container
    │
    ├── PostgreSQL erreichbar?
    │       │
    │       ├── Nein → warten
    │       │
    │       └── Ja
    │
    ▼
Petclinic Container startet
```

Der Init Container muss erfolgreich mit Exit Code `0` beendet werden.

Erst danach werden die normalen Container des Pods gestartet.

Prüfen:

```bash
kubectl -n petclinic describe pod <pod-name>
```

Logs des Init Containers:

```bash
kubectl -n petclinic logs <pod-name> -c wait-for-postgresql
```

Beispiel:

```text
Waiting for PostgreSQL...
PostgreSQL is available!
```

---

# 4. Sidecar Container

Anschließend wurde ein Sidecar Container hinzugefügt.

Der Sidecar soll die Logs der Petclinic-Anwendung aus einer Datei lesen.

Dazu benötigen beide Container Zugriff auf dasselbe Volume.

```text
                 Pod
                  │
       ┌──────────┴──────────┐
       │                     │
       ▼                     ▼
   Petclinic             Log Sidecar
       │                     │
       │ write               │ read
       ▼                     ▼
       ┌─────────────────────┐
       │      emptyDir       │
       │                     │
       │ application.log     │
       └─────────────────────┘
```

---

# 5. Gemeinsames emptyDir

Das gemeinsame Volume wird auf Pod-Ebene definiert:

```yaml
volumes:
  - name: sidecar-logs
    emptyDir: {}
```

Der Petclinic Container mountet das Volume:

```yaml
volumeMounts:
  - name: sidecar-logs
    mountPath: /var/log/petclinic
```

Der Sidecar Container mountet dasselbe Volume:

```yaml
volumeMounts:
  - name: sidecar-logs
    mountPath: /var/log/petclinic
```

Damit sehen beide Container denselben Inhalt:

```text
Petclinic Container
/var/log/petclinic
        │
        │
        ▼
     emptyDir
        ▲
        │
        │
Sidecar Container
/var/log/petclinic
```

---

# 6. Petclinic Logging

Damit Petclinic tatsächlich in eine Datei schreibt, wurde Spring Boot über eine Environment Variable konfiguriert:

```yaml
env:
  - name: LOGGING_FILE_NAME
    value: /var/log/petclinic/application.log
```

Der Petclinic Container verwendet damit:

```text
/var/log/petclinic/application.log
```

als Logdatei.

---

# 7. Log Sidecar

Der Sidecar wartet zunächst darauf, dass die Logdatei existiert.

```yaml
- name: log-sidecar
  image: busybox:1.36

  command:
    - sh
    - -c
    - |
      echo "Waiting for application.log..."

      until [ -f /var/log/petclinic/application.log ]; do
        sleep 1
      done

      echo "application.log found"

      exec tail -f /var/log/petclinic/application.log

  volumeMounts:
    - name: sidecar-logs
      mountPath: /var/log/petclinic
```

Dadurch bleibt der Sidecar Container aktiv und folgt der Logdatei mit:

```bash
tail -f
```

Die Logs können anschließend über Kubernetes abgerufen werden:

```bash
kubectl -n petclinic logs <pod-name> -c log-sidecar
```

Beispiel:

```text
Waiting for application.log...
application.log found

2026-10-07T14:10:38.714Z  INFO ...
Starting AOT-processed PetClinicApplication ...
```

---

# 8. Erkenntnis zum Sidecar Pattern

Das Sidecar Pattern funktioniert nicht automatisch.

Kubernetes stellt lediglich die gemeinsame Umgebung bereit.

Die Anwendung muss Daten erzeugen und der Sidecar muss diese Daten konsumieren.

```text
Application
    │
    │ writes
    ▼
Shared Volume
    │
    │ reads
    ▼
Sidecar
```

In diesem Beispiel:

```text
Spring Boot
    │
    │ application.log
    ▼
emptyDir
    │
    ▼
log-sidecar
    │
    │ tail -f
    ▼
kubectl logs
```

---

# 9. Wechsel vom Deployment zum StatefulSet

Nachdem das Deployment mit Init Container und Sidecar erfolgreich getestet wurde, wird Petclinic vom Deployment zu einem StatefulSet umgebaut.

Das Deployment wird zunächst entfernt:

```bash
kubectl delete -k apps/petclinic
```

Anschließend wird die Anwendung mit dem neuen StatefulSet ausgerollt:

```bash
kubectl apply -k apps/petclinic
```

---

# 10. StatefulSet

Die grundlegende Struktur des StatefulSets:

```yaml
apiVersion: apps/v1
kind: StatefulSet

metadata:
  name: petclinic
  namespace: petclinic

spec:
  replicas: 3

  serviceName: petclinic

  selector:
    matchLabels:
      app.kubernetes.io/name: petclinic

  updateStrategy:
    type: RollingUpdate
```

Der entscheidende Unterschied zum Deployment ist unter anderem:

```yaml
serviceName: petclinic
```

Das StatefulSet erhält dadurch einen festen Service-Bezug.

---

# 11. Stabile Pod-Identität

Beim Deployment entstehen Pods mit dynamischen Namen:

```text
petclinic-8495bcfc48-7j8jf
petclinic-8495bcfc48-d4rgz
petclinic-8495bcfc48-d6pm7
```

Beim StatefulSet erhalten die Pods dagegen stabile, ordinale Namen:

```text
petclinic-0
petclinic-1
petclinic-2
```

Die Identität ist damit nicht zufällig.

```text
StatefulSet
    │
    ├── petclinic-0
    ├── petclinic-1
    └── petclinic-2
```

---

# 12. Verhalten beim Löschen eines Pods

Ein StatefulSet Pod wurde bewusst gelöscht:

```bash
kubectl delete pod petclinic-1 -n petclinic
```

Anschließend wurde mit:

```bash
kubectl get pods -n petclinic -w
```

der Pod-Lifecycle beobachtet.

Beispiel:

```text
petclinic-1   2/2   Terminating
petclinic-1   0/2   Pending
petclinic-1   0/2   Init:0/1
petclinic-1   0/2   PodInitializing
petclinic-1   2/2   Running
```

Wichtig:

Der neue Pod heißt wieder:

```text
petclinic-1
```

Die Identität bleibt erhalten.

---

# 13. PersistentVolumeClaim mit volumeClaimTemplates

Jetzt kommt der entscheidende StatefulSet-Baustein.

Das StatefulSet definiert:

```yaml
volumeClaimTemplates:
  - metadata:
      name: data

    spec:
      accessModes:
        - ReadWriteOnce

      resources:
        requests:
          storage: 1Gi
```

Dadurch erzeugt Kubernetes automatisch einen eigenen PVC für jede StatefulSet-Instanz.

Bei drei Replicas entstehen:

```text
data-petclinic-0
data-petclinic-1
data-petclinic-2
```

Prüfen:

```bash
kubectl get pvc -n petclinic
```

Beispiel:

```text
NAME                 STATUS   CAPACITY   ACCESS MODES   STORAGECLASS
data-petclinic-0     Bound    1Gi        RWO            local-path
data-petclinic-1     Bound    1Gi        RWO            local-path
data-petclinic-2     Bound    1Gi        RWO            local-path
```

---

# 14. volumeMounts bei volumeClaimTemplates

Wichtig:

`volumeClaimTemplates` erstellt die PVCs.

Das Volume wird dadurch aber nicht automatisch in einen Container gemountet.

Dazu ist weiterhin ein `volumeMounts` Eintrag notwendig.

```yaml
containers:
  - name: petclinic

    volumeMounts:
      - name: data
        mountPath: /data
```

Der Name muss mit dem Namen aus `volumeClaimTemplates` übereinstimmen:

```yaml
volumeClaimTemplates:
  - metadata:
      name: data
```

und:

```yaml
volumeMounts:
  - name: data
    mountPath: /data
```

---

# 15. Zwei unterschiedliche Volume-Konzepte

Im StatefulSet werden zwei unterschiedliche Storage-Konzepte verwendet.

## Temporäres shared Volume

Für die Kommunikation zwischen Petclinic und Sidecar:

```yaml
volumes:
  - name: sidecar-logs
    emptyDir: {}
```

Dieses Volume wird von beiden Containern verwendet:

```text
Petclinic
    │
    ▼
application.log
    │
    ▼
emptyDir
    │
    ▼
Log Sidecar
```

---

## Persistentes StatefulSet Storage

Für jeden StatefulSet Pod:

```yaml
volumeClaimTemplates:
  - metadata:
      name: data
```

Dadurch:

```text
petclinic-0
    │
    ▼
data-petclinic-0

petclinic-1
    │
    ▼
data-petclinic-1

petclinic-2
    │
    ▼
data-petclinic-2
```

---

# 16. Gesamte Architektur

Nach dem Umbau sieht die Architektur folgendermaßen aus:

```text
                         StatefulSet
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
         petclinic-0    petclinic-1    petclinic-2
              │              │              │
        ┌─────┴─────┐  ┌─────┴─────┐  ┌─────┴─────┐
        │           │  │           │  │           │
        ▼           ▼  ▼           ▼  ▼           ▼
    Petclinic   Sidecar  Petclinic Sidecar ...
        │           │
        └─────┬─────┘
              │
           emptyDir
              │
        application.log

              +

       Persistent Storage

       petclinic-0
            │
            ▼
     data-petclinic-0

       petclinic-1
            │
            ▼
     data-petclinic-1

       petclinic-2
            │
            ▼
     data-petclinic-2
```

---

# 17. Deployment vs. StatefulSet

| Eigenschaft | Deployment | StatefulSet |
|---|---|---|
| Pod-Identität | dynamisch | stabil |
| Pod-Namen | Hash-basiert | ordinal |
| Beispiel | `petclinic-8495bc48-xxxxx` | `petclinic-0` |
| Controller | Deployment / ReplicaSet | StatefulSet |
| `serviceName` | nicht erforderlich | Bestandteil des StatefulSets |
| `volumeClaimTemplates` | nein | ja |
| eigener PVC pro Pod | nicht automatisch | ja |
| stabile Storage-Zuordnung | nicht primäres Konzept | ja |
| typischer Einsatz | stateless Anwendungen | stateful Anwendungen |

---

# 18. Wichtige CKA-Merksätze

### Deployment

> Ein Deployment verwaltet ReplicaSets und stellt typischerweise austauschbare Pods für stateless Workloads bereit.

### Init Container

> Init Container werden vor den normalen Containern eines Pods ausgeführt und müssen erfolgreich abgeschlossen werden.

### Sidecar

> Ein Sidecar läuft als zusätzlicher Container im selben Pod und kann über gemeinsame Volumes Daten mit dem Hauptcontainer austauschen.

### emptyDir

> `emptyDir` stellt temporären Speicher innerhalb eines Pods bereit und kann von mehreren Containern desselben Pods gemeinsam verwendet werden.

### StatefulSet

> Ein StatefulSet stellt Pods mit stabiler Identität und definierter Storage-Zuordnung bereit.

### volumeClaimTemplates

> `volumeClaimTemplates` erzeugt automatisch einen eigenen PVC für jede StatefulSet-Instanz.

### volumeMounts

> `volumeMounts` bestimmt, an welchem Pfad ein Volume innerhalb eines Containers verfügbar ist.

---

# 19. Wichtige Befehle

Deployment / StatefulSet anzeigen:

```bash
kubectl get deployment,statefulset -n petclinic
```

Pods:

```bash
kubectl get pods -n petclinic
```

Pods live beobachten:

```bash
kubectl get pods -n petclinic -w
```

PVCs:

```bash
kubectl get pvc -n petclinic
```

StatefulSet:

```bash
kubectl get statefulset -n petclinic
```

StatefulSet detailliert:

```bash
kubectl describe statefulset petclinic -n petclinic
```

Pod detailliert:

```bash
kubectl describe pod petclinic-0 -n petclinic
```

Init Container Logs:

```bash
kubectl logs petclinic-0 -n petclinic -c wait-for-postgresql
```

Sidecar Logs:

```bash
kubectl logs petclinic-0 -n petclinic -c log-sidecar
```

Petclinic Logs:

```bash
kubectl logs petclinic-0 -n petclinic -c petclinic
```

Pod löschen:

```bash
kubectl delete pod petclinic-1 -n petclinic
```

---

# 20. Wichtigste Erkenntnis des praktischen Labs

Der entscheidende Unterschied zwischen Deployment und StatefulSet wurde nicht nur theoretisch betrachtet, sondern praktisch im Cluster getestet.

### Deployment

```text
Pod wird gelöscht
       │
       ▼
neuer Pod
       │
       ▼
neue Identität
```

### StatefulSet

```text
petclinic-1 wird gelöscht
       │
       ▼
neuer Pod
       │
       ▼
wieder petclinic-1
       │
       ▼
wieder data-petclinic-1
```

Damit wird deutlich:

```text
Deployment
→ austauschbare Pods

StatefulSet
→ stabile Pod-Identität
→ stabile Storage-Zuordnung
```

---

# 21. CKA Relevanz

Diese Übung deckt mehrere relevante CKA-Themen gleichzeitig ab:

```text
Workloads & Scheduling
│
├── Deployments
├── ReplicaSets
├── Rolling Updates
├── Init Containers
├── Sidecar Containers
├── StatefulSets
│
└── Storage
    ├── StorageClass
    ├── PersistentVolume
    ├── PersistentVolumeClaim
    ├── volumeClaimTemplates
    └── Volume Mounts
```

Besonders wichtig ist das Verständnis der Beziehung:

```text
StatefulSet
    │
    ├── Pod Identity
    │
    └── volumeClaimTemplates
            │
            ▼
           PVC
            │
            ▼
           PV
            │
            ▼
       StorageClass
            │
            ▼
        Storage
```

Damit sind Deployment, Init Container, Sidecar Container und StatefulSet nicht mehr nur einzelne Kubernetes-Begriffe, sondern Teil eines zusammenhängenden Workload- und Storage-Modells.
