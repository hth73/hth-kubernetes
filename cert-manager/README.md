# Kubernetes Cert-Manager

<img src="https://img.shields.io/badge/Cert%20Manager-326CE5?style=flat&logo=kubernetes&labelColor=ffffff&logoColor=326CE5" /> <img src="https://img.shields.io/badge/Helm-0F1689?style=flat&logo=helm&labelColor=ffffff&logoColor=0F1689" />

[Cert-Manager Documentation](https://cert-manager.io/docs)

---

## Beschreibung

Mit folgenden Befehlen wird der `Cert-Manager` in einem Kubernetes Cluster bereitgestellt.

```bash
## Install Kubernetes Cert-Manager
helm repo add jetstack https://charts.jetstack.io --force-update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.20.2 \
  --set crds.enabled=true \
  --set crds.keep=true \
  --set startupapicheck.enabled=false

## Uninstall Kubernetes Cert-Manager
helm uninstall cert-manager -n cert-manager

kubectl get all -n cert-manager
# NAME                                           READY   STATUS
# pod/cert-manager-56d4c7dfb7-ft74l              1/1     Running
# pod/cert-manager-cainjector-6dc54dcd78-dd6gw   1/1     Running
# pod/cert-manager-webhook-5d74598b49-hbz9r      1/1     Running
# ...

## Debugging bei Bedarf aktivieren. Wert wird von --v=2 auf --v=5 verändert. Dadurch wird detaillierter geloggt.
kubectl edit deployment cert-manager -n cert-manager
# spec:
#   containers:
#   - args:
#     - --v=5

kubectl rollout restart deployment cert-manager -n cert-manager
kubectl logs -n cert-manager -l app=cert-manager -f
```

Mit folgender YAML Konfiguration erstellen wir eine SelfSign Root-CA und eine SelfSign Sub-CA Zertifizierungstelle.
Dazu wird ein `kind: ClusterIssuer` benötigt, der für alle Namespace zur Verfügung steht. 
Ein `kind: Issuer` ist nur für einen expliziten Namespace zuständig.

## Root-CA ClusterIssuer

```yaml
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: htdom-root-ca
  namespace: cert-manager
spec:
  selfSigned: {}
```

### Root-CA Zertifikat

```yaml
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: htdom-root-ca
  namespace: cert-manager
spec:
  commonName: "htdom-root-ca"
  secretName: "htdom-root-ca-secret" # root-ca secret
  isCA: true
  duration: 43830h # 5 Years
  renewBefore: 720h # renewal 30 days before expires
  privateKey:
    rotationPolicy: Never
    algorithm: RSA
    size: 4096
  usages:
  - digital signature
  - key encipherment
  - cert sign
  subject:
    organizations:
      - "HTDOM Inc." # (O) Organization
    organizationalUnits:
      - "IT" # (OU) Organizational unit
    countries:
      - "DE" # (C) Country
    localities:
      - "Muenchen" # (L) Location
    provinces:
      - "Bayern" # (ST) Province
  issuerRef:
    name: htdom-root-ca
    kind: ClusterIssuer
```

## Sub-CA ClusterIssuer

```yaml
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: htdom-sub-ca
  namespace: cert-manager
spec:
  ca:
    secretName: htdom-sub-ca-secret
```

### Sub-CA Zertifikat

```yaml
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: htdom-sub-ca
  namespace: cert-manager
spec:
  commonName: "htdom-sub-ca"
  secretName: "htdom-sub-ca-secret"
  isCA: true
  duration: 26280h # 3 Jahre
  renewBefore: 720h # 30 Tage vor Ablauf erneuern
  privateKey:
    algorithm: RSA
    size: 4096
    rotationPolicy: Always
  usages:
    - digital signature
    - key encipherment
    - cert sign
  subject:
    organizations:
      - "HTDOM Inc." # (O) Organization
    organizationalUnits:
      - "IT" # (OU) Organizational unit
    countries:
      - "DE" # (C) Country
    localities:
      - "Muenchen" # (L) Location
    provinces:
      - "Bayern" # (ST) Province
  issuerRef:
    name: htdom-root-ca
    kind: ClusterIssuer
```

## Cert-Manger ausrollen und überprüfen
```bash
## Root und Sub-CA erstellen
kubectl apply -f cert-manager/root_ca_cluster_issuer.yaml
kubectl apply -f cert-manager/root_ca_certificate.yaml
kubectl apply -f cert-manager/sub_ca_cluster_issuer.yaml
kubectl apply -f cert-manager/sub_ca_certificate.yaml

## Cert-Manager Installation überprüfen
kubectl get clusterissuers
kubectl describe clusterissuers
kubectl get secrets -n cert-manager

## Zertifikate exportieren
kubectl get secret htdom-root-ca-secret -n cert-manager -o jsonpath='{.data.tls\.crt}' | base64 --decode
kubectl get secret htdom-sub-ca-secret -n cert-manager -o jsonpath='{.data.tls\.crt}' | base64 --decode

## Zertifikate überprüfen
openssl x509 -in htdom-root-ca.crt -text -noout
openssl x509 -in htdom-sub-ca.crt -text -noout

## Zertifikat Chain bilden und überprüfen
cat htdom-root-ca.crt htdom-sub-ca.crt > chain.crt
openssl verify -CAfile htdom-root-ca.crt chain.crt
# combined-chain.crt: OK

## Secrets anzeigen lassen
kubectl get secret htdom-root-ca-secret -n cert-manager -o yaml
kubectl get secret htdom-sub-ca-secret -n cert-manager -o yaml

## Server Zertifikat anzeigen lassen
kubectl describe certificate podinfo.htdom.lan -n podinfo
```
