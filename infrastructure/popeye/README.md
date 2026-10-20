# Popeye Kubernetes Checks und Lösungen

* [Popeye Kubernetes Live Cluster Linter](https://popeyecli.io/)
* [Popeye error codes](https://popeyecli.io/docs/codes.html)

---

[Back to home](../../README_k3s.md)

---

## Beispiel: podinfo im K3s-Cluster

### 1. Unnamed Port – POP-108
**Problem:** Ein Container-Port besitzt keinen Namen.

**Lösung:** Ports sinnvoll benennen, zum Beispiel `http`.

```yaml
ports:
  - name: http
    containerPort: 9898
    protocol: TCP
```

### 2. Use of target port # – POP-1102
**Problem:** Der Service verwendet einen numerischen Target-Port statt eines benannten Ports.

**Lösung:** Den Target-Port auf den Namen des Container-Ports setzen.

```yaml
containers:
  - name: podinfo
    ...
ports:
  - name: http
    containerPort: 9898
    protocol: TCP
```

### 3. Ingress backend uses a port# – POP-1403
**Problem:** Der Ingress referenziert den Service-Port numerisch.

**Lösung:** Den benannten Service-Port verwenden.

```yaml
spec:
  ingressClassName: traefik
  ...
  rules:
    ...
        backend:
          service:
            name: podinfo
            port:
              name: http
```

### 4. Liveness/Readiness uses a port# – POP-105
**Problem:** Die Health-Checks verwenden einen numerischen Port.

**Lösung:** Den benannten Container-Port verwenden.

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: http

readinessProbe:
  httpGet:
    path: /readyz
    port: http
```

Die Endpunkte müssen von der jeweiligen Anwendung unterstützt werden.

### 5. Pod could be running as root – POP-302
### 6. Container could be running as root – POP-306

**Problem:** Die Sicherheitskonfiguration erzwingt nicht ausdrücklich, dass der Container als Nicht-Root läuft.

**Lösung:** Pod- und Container-SecurityContext setzen.

Pod-Ebene unter `spec.template.spec`:

```yaml
spec:
  serviceAccountName: podinfo
  securityContext:
    runAsNonRoot: true
    runAsUser: 100
    runAsGroup: 101
    seccompProfile:
      type: RuntimeDefault

```

Container-Ebene unter dem jeweiligen Container:

```yaml
  containers:
    - ...
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
```

Bei podinfo entsprechen UID 100 und GID 101 dem zuvor geprüften Benutzer `app`. Bei anderen Images müssen Benutzer, Gruppen und benötigte Capabilities geprüft werden.

### 7. Pod ingress is not secured by a network policy – POP-1204

**Problem:** Es gibt keine passende NetworkPolicy, die den eingehenden Verkehr einschränkt.

**Lösung bei podinfo:** Nur Traefik aus `kube-system` auf TCP-Port 9898 zulassen.

Datei: `networkpolicy.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: podinfo-ingress
  namespace: podinfo

spec:
  podSelector:
    matchLabels:
      app: podinfo
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              app.kubernetes.io/name: traefik
      ports:
        - protocol: TCP
          port: 9898
```

Wichtig: `namespaceSelector` und `podSelector` stehen im selben Eintrag unter `from`. Beide Bedingungen müssen erfüllt sein.

### 8. Pod egress is not secured by a network policy – POP-1204

**Problem:** Der ausgehende Netzwerkverkehr ist nicht durch eine passende Egress-Policy eingeschränkt.

**Lösung bei podinfo:** Egress vollständig sperren, sofern die Anwendung keine ausgehenden Verbindungen benötigt.

Datei: `networkpolicy.yaml` Ingress und Egress sind in einer Datei definiert.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
...

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: podinfo-egress
  namespace: podinfo

spec:
  podSelector:
    matchLabels:
      app: podinfo
  policyTypes:
    - Egress
```

Da keine Egress-Regeln definiert sind, wird ausgehender Verkehr für die ausgewählten Pods gesperrt. Bei anderen Anwendungen müssen notwendige Ziele, beispielsweise DNS, Datenbanken oder externe APIs, ausdrücklich berücksichtigt werden.

Die tatsächliche Durchsetzung der Regeln muss durch das Netzwerk-Plugin gewährleistet sein.

### 9. Pod has no associated PodDisruptionBudget – POP-206

**Problem:** Für die ausgewählten Pods existiert kein passendes PodDisruptionBudget (PDB).

**Lösung bei podinfo:** Mit zwei Replikaten maximal einen Pod bei unterstützten freiwilligen Unterbrechungen gleichzeitig nicht verfügbar werden lassen.

Datei: `poddisruptionbudget.yaml`

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: podinfo
  namespace: podinfo
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app: podinfo
```

Das PDB schützt nicht vor ungeplanten Ausfällen wie einem Node-Crash. Es ist nicht für jede Anwendung zwingend erforderlich.

### 10. Uses "default" ServiceAccount – POP-300

**Problem:** Der Pod verwendet den standardmäßigen ServiceAccount seines Namespace.

**Lösung bei podinfo:** Eigenen ServiceAccount erstellen und den automatischen Token-Mount deaktivieren.

Datei: `serviceaccount.yaml`

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: podinfo
  namespace: podinfo
automountServiceAccountToken: false
```

Im Deployment unter `spec.template.spec`:

```yaml
spec:
  replicas: 2
  selector:
    matchLabels:
      app: podinfo
  template:
    ...
    spec:
      serviceAccountName: podinfo
      ...
```

Das automatische Einhängen des API-Tokens ist damit deaktiviert, sofern es nicht auf Pod-Ebene explizit anders konfiguriert wird. Anwendungen, die Kubernetes-API-Zugriff benötigen, müssen individuell konfiguriert werden.

---

## Änderungen anwenden und prüfen

Beispiel für einzelne Manifeste:

```bash
kubectl apply --dry-run=server -f <manifest.yaml>
kubectl apply -f <manifest.yaml>

kubectl -n podinfo rollout status deployment/podinfo
kubectl -n podinfo get pods
kubectl -n podinfo get networkpolicy
kubectl -n podinfo get pdb
kubectl -n podinfo get serviceaccount
```

Danach Popeye ausführen:

```bash
popeye -n podinfo
```

Alternativ den vorhandenen Shell-Helper verwenden:

```bash
popeye-scan -n podinfo
```

## Ergebnis bei podinfo

Nach den beschriebenen Änderungen meldete Popeye:

- Grade A
- Score 100
- Keine Fehler, Warnungen oder Hinweise in den geprüften Ressourcen

Ein sauberer Popeye-Report ist eine gute Qualitätskontrolle, aber keine vollständige Sicherheitsgarantie. Netzwerkregeln sollten zusätzlich auf ihre tatsächliche Wirkung getestet werden.
