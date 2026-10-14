# Kustomize – Kubernetes-Manifeste verwalten

[Back to home](../../README.md)

---

## 1. Was ist Kustomize?

Kustomize ist ein Werkzeug zur Anpassung und Zusammenstellung von Kubernetes-Manifesten. Es ist in `kubectl` integriert und benötigt keine zusätzliche Template-Engine.

Mit Kustomize können wir:

- mehrere YAML-Manifeste zu einer Anwendung zusammenfassen
- bestehende Manifeste patchen, ohne die Originaldateien zu verändern
- wiederverwendbare Ressourcen und Templates definieren
- Umgebungsunterschiede wie Development und Production abbilden
- Images, Replicas, Labels und Namespaces anpassen
- Konfigurationen für Argo CD bereitstellen

Die zentrale Datei eines Kustomize-Verzeichnisses heißt `kustomization.yaml`.

## 2. Grundlegende Arbeitsweise

Beispiel einer einfachen Anwendung:

```text
apps/
└── example/
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    └── kustomization.yaml
```

Beispiel für `kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
  - ingress.yaml
```

Die aufgeführten Ressourcen werden von Kustomize zusammengeführt.

### Manifeste rendern

```bash
kubectl kustomize apps/example
```

Der Befehl gibt die fertig zusammengesetzten Manifeste aus, verändert aber nichts im Cluster.

### Ressourcen anwenden

```bash
kubectl apply -k apps/example
```

Dieser Befehl rendert die Konfiguration und wendet sie auf den Kubernetes-Cluster an.

### Unterschied

| Befehl | Funktion |
|---|---|
| `kubectl kustomize` | Manifeste rendern und überprüfen |
| `kubectl apply -k` | Manifeste rendern und anwenden |
| `kubectl diff -k` | Geplante Änderungen mit dem Cluster vergleichen |

Vor Änderungen an produktiven oder zustandsbehafteten Anwendungen sollte der gerenderte Zustand geprüft werden.

---

## 3. Ressourcen mit `resources` zusammenführen

Mit `resources` werden bestehende Manifeste oder weitere Kustomize-Verzeichnisse eingebunden.

```yaml
resources:
  - namespace.yaml
  - deployment.yaml
  - service.yaml
  - ingress.yaml
```

Auch ein Unterverzeichnis mit eigener `kustomization.yaml` kann als Ressource eingebunden werden:

```yaml
resources:
  - database/
  - backend/
  - frontend/
```

Das ist hilfreich, wenn eine Anwendung aus mehreren Komponenten besteht.

**Wichtig:** Kustomize besitzt standardmäßig eine Pfadbeschränkung. Ressourcen dürfen nicht beliebig außerhalb des Build-Verzeichnisses geladen werden.

---

## 4. Ressourcen direkt patchen

Kustomize kann bestehende Ressourcen ändern, ohne die ursprünglichen Manifeste anzupassen.

Ein Beispiel: Eine Deployment-Datei definiert eine Replika. Für eine bestimmte Konfiguration soll die Anwendung zwei Replikas verwenden.

### Beispiel mit einem strategischen Merge-Patch

Patch-Datei `deployment-patch.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-app
spec:
  replicas: 2
```

Einbindung in `kustomization.yaml`:

```yaml
resources:
  - deployment.yaml

patches:
  - path: deployment-patch.yaml
```

Kustomize führt den Patch mit dem vorhandenen Deployment zusammen.

Diese Variante eignet sich gut, wenn nur einzelne Felder einer Ressource angepasst werden sollen.

---

## 5. Inline-Patches mit JSON6902

Für kleine Änderungen können Patches direkt in der `kustomization.yaml` definiert werden. Eine separate Patch-Datei ist dann nicht erforderlich.

Beispiel:

```yaml
resources:
  - deployment.yaml

patches:
  - target:
      group: apps
      version: v1
      kind: Deployment
      name: example-app
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 2
```

### Häufige Operationen

| Operation | Bedeutung |
|---|---|
| `add` | Feld hinzufügen |
| `replace` | Vorhandenes Feld ersetzen |
| `remove` | Feld entfernen |
| `test` | Vorhandenen Wert überprüfen |
| `copy` | Wert kopieren |
| `move` | Wert verschieben |

Bei `replace` muss der angegebene JSON-Pointer bereits existieren. Bei `add` kann ein Feld hinzugefügt werden.

### JSON-Pointer und Labels

Kubernetes-Labels enthalten häufig einen Schrägstrich:

```text
app.kubernetes.io/name
```

Im JSON-Pointer muss der Schrägstrich als `~1` geschrieben werden:

```yaml
path: /metadata/labels/app.kubernetes.io~1name
```

Für eine Tilde wird `~0` verwendet.

### Wann Inline-Patches sinnvoll sind

- wenige, übersichtliche Änderungen
- app-spezifische Anpassungen
- kleine Unterschiede bei Namen, Labels oder Replicas
- Änderungen, die unmittelbar bei der Anwendung erkennbar sein sollen

Bei sehr vielen oder umfangreichen Patches sind separate Dateien oft übersichtlicher.

---

## 6. Zentrale Templates wiederverwenden

In unserem Homelab verwenden wir zentrale Templates unter `apps/templates/`.

Beispiel:

```text
apps/
├── templates/
│   ├── namespace/
│   │   ├── kustomization.yaml
│   │   └── namespace.yaml
│   ├── certificate/
│   │   ├── kustomization.yaml
│   │   └── certificate.yaml
│   └── pdb/
│       ├── kustomization.yaml
│       └── pdb.yaml
├── todo/
│   └── kustomization.yaml
└── podinfo/
    └── kustomization.yaml
```

Die Templates enthalten generische Platzhalterwerte, beispielsweise:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
  namespace: app-pdb
  labels:
    app.kubernetes.io/name: app-pdb
    app.kubernetes.io/component: app-pdb
    app: app-pdb
    environment: app-pdb
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: app-pdb
      app.kubernetes.io/component: app-pdb
```

Die konkreten Werte werden durch Patches in der jeweiligen Anwendung ersetzt.

### Zentrales Template einbinden

```yaml
resources:
  - ../templates/pdb/pdb.yaml
```

### Inline-Patch für Todo

```yaml
patches:
  - target:
      group: policy
      version: v1
      kind: PodDisruptionBudget
      name: app-pdb
    patch: |-
      - op: replace
        path: /metadata/name
        value: todo-ui
      - op: replace
        path: /metadata/namespace
        value: todo
      - op: replace
        path: /metadata/labels/app.kubernetes.io~1name
        value: todo-ui
      - op: replace
        path: /metadata/labels/app.kubernetes.io~1component
        value: ui
      - op: replace
        path: /metadata/labels/app
        value: todo
      - op: replace
        path: /spec/selector/matchLabels/app.kubernetes.io~1name
        value: todo-ui
      - op: replace
        path: /spec/selector/matchLabels/app.kubernetes.io~1component
        value: ui
```

Der Patch wird anhand des ursprünglichen Ressourcennamens `app-pdb` ausgewählt. Erst danach ändert er den Namen in `todo-ui`.

### Welche Ressourcen lassen sich so wiederverwenden?

- Namespaces
- PodDisruptionBudgets
- Certificates von cert-manager
- ServiceAccounts für einfache, standardisierte Anwendungen
- NetworkPolicies, sofern die Regeln tatsächlich übereinstimmen
- weitere Ressourcen mit wiederkehrender Struktur

**Nicht jede Ressource sollte zwingend ein Template werden.** Anwendungsspezifische ServiceAccounts, komplexe NetworkPolicies oder Datenbankkonfigurationen können besser als individuelle Manifeste gepflegt werden.

### Wichtiger Hinweis zur Pfadbeschränkung

Weil `apps/todo` auf Dateien unter `apps/templates/` zugreift, verlässt der Build den eigenen Verzeichnisbereich.

Für unser Homelab haben wir deshalb in Argo CD folgende Option konfiguriert:

```yaml
data:
  kustomize.buildOptions: --load-restrictor LoadRestrictionsNone
```

Der lokale Build erfolgt entsprechend mit:

```bash
kubectl kustomize --load-restrictor LoadRestrictionsNone apps/todo
```

Diese Einstellung lockert die Sicherheitsgrenze für alle Kustomize-Anwendungen dieses Argo-CD-Servers. In stärker isolierten Umgebungen sollte stattdessen eine Struktur bevorzugt werden, die ohne diese Lockerung auskommt.

---

## 7. Argo-CD-Konfiguration mit Kustomize patchen

Kustomize eignet sich nicht nur für Anwendungen. Wir verwenden es auch, um die Argo-CD-Konfiguration deklarativ zu verwalten.

Verzeichnis:

```text
infrastructure/
└── argocd/
    ├── kustomization.yaml
    ├── argocd-patch.yaml
    ├── ingress.yaml
    ├── server-certificate.yaml
    ├── todo-application.yaml
    └── yelb-application.yaml
```

### Mehrere ConfigMaps in einer YAML-Datei

Datei `argocd-patch.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  kustomize.buildOptions: --load-restrictor LoadRestrictionsNone

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
  namespace: argocd
data:
  server.insecure: "true"
```

Die beiden ConfigMaps sind vollständige Kubernetes-Ressourcen. Sie werden deshalb über `resources` eingebunden:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ingress.yaml
  - server-certificate.yaml
  - todo-application.yaml
  - yelb-application.yaml
  - argocd-patch.yaml
```

### Warum funktioniert das?

Kustomize führt Ressourcen mit identischer API-Version, Art, Name und Namespace zusammen. So können die gewünschten `data`-Einträge mit den bereits vorhandenen ConfigMaps kombiniert werden.

Die Konfiguration lässt sich anschließend mit folgendem Befehl anwenden:

```bash
kubectl apply -k infrastructure/argocd
```

Änderungen an `argocd-cm` oder `argocd-cmd-params-cm` starten die zugehörigen Argo-CD-Deployments nicht automatisch neu. Falls ein Neustart für die geänderte Einstellung erforderlich ist, muss er gesondert berücksichtigt werden.

---

## 8. Weitere nützliche Kustomize-Funktionen

### 8.1 Namespace zentral setzen

Mit `namespace` können Namespaces für namespaced Ressourcen gesetzt werden:

```yaml
namespace: todo
```

Das ersetzt in vielen Fällen die wiederholte Pflege von `metadata.namespace` in einzelnen Ressourcen.

Namespace-Objekte selbst sind clusterweit und erhalten dadurch keinen eigenen `metadata.namespace`-Wert.

### 8.2 Gemeinsame Labels ergänzen

```yaml
commonLabels:
  environment: dev
  managed-by: kustomize
```

Kustomize kann damit Labels auf Ressourcen anwenden. Da Labels auch Selektoren beeinflussen können, sollte bei bestehenden Anwendungen geprüft werden, welche Felder tatsächlich geändert werden.

Bei neueren Kustomize-Versionen ist für allgemeine Metadaten häufig `labels` die flexiblere Variante.

### 8.3 Images zentral ändern

```yaml
images:
  - name: docker.io/hellemon/docker-repo
    newTag: todo-frontend-0.1.4
```

Der Image-Name muss mit dem Image-Namen im Deployment übereinstimmen. Mit `images` lassen sich Tags aktualisieren, ohne die Deployment-Datei direkt zu ändern.

Das ist nützlich für Image-Upgrades und für automatisierte Image-Updates.

### 8.4 Replicas festlegen

```yaml
replicas:
  - name: todo-ui
    count: 2
```

Damit kann die Anzahl der Replikas zentral angepasst werden.

Diese Einstellung sollte mit einer gegebenenfalls verwendeten automatischen Skalierung abgestimmt werden.

### 8.5 ConfigMaps und Secrets generieren

Kustomize kann ConfigMaps aus Dateien oder Literalen erzeugen:

```yaml
configMapGenerator:
  - name: app-config
    literals:
      - LOG_LEVEL=info
      - APP_ENV=development
```

Der Generator erzeugt eine ConfigMap. Standardmäßig erhält sie einen Hash im Namen, wodurch referenzierende Ressourcen bei Inhaltsänderungen aktualisiert werden können.

Auch `secretGenerator` ist verfügbar. Sensible Werte sollten jedoch nicht unverschlüsselt im Git-Repository abgelegt werden. Für unser Homelab verwenden wir bei Secrets bereits SOPS.

### 8.6 Overlays für verschiedene Umgebungen

Eine mögliche Struktur:

```text
apps/
└── example/
    ├── base/
    │   ├── deployment.yaml
    │   ├── service.yaml
    │   └── kustomization.yaml
    └── overlays/
        ├── dev/
        │   └── kustomization.yaml
        └── production/
            └── kustomization.yaml
```

Die `base` enthält die gemeinsamen Ressourcen. Overlays passen diese für eine bestimmte Umgebung an.

Beispielsweise können Development und Production unterschiedliche Replicas, Ressourcenlimits, Images oder Ingress-Konfigurationen verwenden.

Das vermeidet doppelte Manifeste und hält umgebungsspezifische Unterschiede nachvollziehbar.

---

## 9. Kustomize und Argo CD

Argo CD kann ein Repository-Verzeichnis mit einer `kustomization.yaml` automatisch als Kustomize-Anwendung erkennen.

In unserem Homelab sieht das für Todo vereinfacht so aus:

```yaml
spec:
  source:
    repoURL: https://github.com/hth73/hth-kubernetes.git
    targetRevision: main
    path: apps/todo
  destination:
    server: https://kubernetes.default.svc
    namespace: todo
```

Der GitOps-Ablauf ist:

1. Manifeste lokal ändern.
2. Kustomize-Build prüfen.
3. Änderungen committen und pushen.
4. Argo CD erkennt den neuen Git-Stand.
5. Auto-Sync wendet die gewünschten Ressourcen an.
6. Argo CD bewertet Sync- und Health-Status.

Bei aktivem Auto-Sync sind manuelle `kubectl apply`-Aufrufe für von Argo CD verwaltete Anwendungsressourcen im normalen GitOps-Ablauf nicht notwendig.

### Lokale Prüfung vor dem Commit

```bash
kubectl kustomize --load-restrictor LoadRestrictionsNone apps/todo
kubectl kustomize infrastructure/argocd
git diff --check
```

Anschließend Änderungen prüfen, committen und pushen.

---

## 10. Best Practices für unser Homelab

- **Kleine Änderungen:** Inline-Patches verwenden.
- **Größere Änderungen:** Separate Patch-Dateien verwenden.
- **Wiederkehrende Ressourcen:** Zentrale Templates verwenden, wenn die Struktur wirklich standardisiert ist.
- **Anwendungsspezifische Ressourcen:** Individuell pflegen, wenn sie spezielle Anforderungen haben.
- **Vor dem Sync:** Den gerenderten Build überprüfen.
- **GitOps:** Änderungen an verwalteten Ressourcen über Git ausrollen.
- **Secrets:** Keine Passwörter oder Tokens im Klartext committen.
- **Stateful Workloads:** Änderungen an Datenbanken und Storage besonders sorgfältig prüfen.
- **Security:** Sicherheitsoptionen nicht nur deshalb lockern, weil ein lokaler Build sonst fehlschlägt.

## 11. Referenzbefehle

| Aufgabe | Befehl |
|---|---|
| Kustomize rendern | `kubectl kustomize apps/todo` |
| Templates außerhalb des Build-Verzeichnisses laden | `kubectl kustomize --load-restrictor LoadRestrictionsNone apps/todo` |
| Kustomize-Ressourcen anwenden | `kubectl apply -k apps/todo` |
| Geplante Änderungen anzeigen | `kubectl diff -k apps/todo` |
| Argo-CD-Konfiguration rendern | `kubectl kustomize infrastructure/argocd` |
| Argo-CD-Konfiguration anwenden | `kubectl apply -k infrastructure/argocd` |

## Fazit

Kustomize ermöglicht es, Kubernetes-Manifeste modular, wiederverwendbar und nachvollziehbar zu pflegen. In unserem Homelab nutzen wir es sowohl für anwendungsspezifische Anpassungen als auch für zentrale Templates und die deklarative Argo-CD-Konfiguration.

Die wichtigste Regel bleibt: **Erst rendern und prüfen, dann committen und pushen – Argo CD übernimmt anschließend den Rollout.**
