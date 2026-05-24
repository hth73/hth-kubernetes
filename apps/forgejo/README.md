# Forgejo Git Server mit sqlite

<img src="https://img.shields.io/badge/Forgejo-FB923C?style=flat&logo=forgejo&labelColor=ffffff&logoColor=FB923C" /> <img src="https://img.shields.io/badge/SQLite-003B57?style=flat&logo=sqlite&labelColor=ffffff&logoColor=003B57" />

[Forgejo Helm Chart](https://code.forgejo.org/forgejo-helm/forgejo-helm)

---

[Back to home](../../README.md)

---

## Beschreibung

Forgejo ist eine quelloffene, ressourcenschonende Plattform für die Softwareentwicklung und Versionsverwaltung, die auf Git basiert. Sie fungiert als Alternative zu Plattformen wie GitHub oder GitLab, bietet ähnliche kollaborative Funktionen und lässt sich einfach selbst auf eigenen Servern oder Kubernetes betreiben.

## Forgejo Helm Chart

```bash
## Forgejo Helm Chart erforschen
helm show values oci://code.forgejo.org/forgejo-helm/forgejo
helm show values oci://code.forgejo.org/forgejo-helm/forgejo > values.yaml

cat values.yaml                                                           
# Default values for gitea.
# This is a YAML-formatted file.
## @section Global
global:
  imageRegistry: ''
  hostAliases: []
  # - ip: 192.168.137.2

## Forgejo Helm Chart gerendert ausgeben
helm template forgejo oci://code.forgejo.org/forgejo-helm/forgejo -f values.yaml > rendered.yaml

cat rendered.yaml                                                      
---
# Source: forgejo/templates/gitea/admin-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: forgejo-admin
  namespace: "default"
  labels:
    helm.sh/chart: forgejo-17.1.0
    app: forgejo
```

## Meine values.yaml File

```yaml
gitea:
  admin:
    existingSecret: forgejo-admin-secret
    email: hth@htdom.lan

  config:
    APP_NAME: HTH
    RUN_MODE: prod
    APP_SLOGAN: Deploy at scale. Sleep at night.

    server:
      DOMAIN: git.htdom.lan
      SSH_DOMAIN: git.htdom.lan
      ROOT_URL: https://git.htdom.lan
...
```

## Forgejo Server deployen

```bash
helm install forgejo oci://code.forgejo.org/forgejo-helm/forgejo -n forgejo --create-namespace -f apps/forgejo/values.yaml

## Server Zertifikat anlegen
kubectl apply -f apps/forgejo/server-certificate.yaml

## Deployment überprüfen
kubectl describe pod -n forgejo
kubectl logs -n forgejo deploy/forgejo --tail=100
kubectl get secret -n forgejo

kubectl exec -it -n forgejo deploy/forgejo -- cat /data/gitea/conf/app.ini

curl -iv https://git.htdom.lan       
# HTTP/2 200 
# cache-control: max-age=0, private, must-revalidate, no-transform
# ...
```

## SOPS: Secrets OPerationS integration

```bash
# --------------------------------------------------------------------------------
# SOPS installation
# https://getsops.io - https://github.com/getsops
# --------------------------------------------------------------------------------
cd /tmp
wget https://github.com/getsops/sops/releases/download/v3.12.2/sops-v3.12.2.linux.amd64
mv sops-v3.12.2.linux.amd64 ~/bin/sops
chmod +x ~/bin/sops

sops --version --check-for-updates
sops 3.12.2 (latest)

# --------------------------------------------------------------------------------
# Set up sops with age and age-keygen
# https://github.com/FiloSottile/age
# --------------------------------------------------------------------------------
wget https://github.com/FiloSottile/age/releases/download/v1.3.1/age-v1.3.1-linux-amd64.tar.gz
tar xvf age-v1.3.1-linux-amd64.tar.gz
mv age/age ~/bin
mv age/age-keygen ~/bin

age -version
age-keygen -version

# ---

mkdir ~/.sops
age-keygen -o ~/.sops/sops_key.txt

cat ~/.sops/sops_key.txt

vi ~/.zshrc
export SOPS_AGE_KEY_FILE="${HOME}/.sops/sops_key.txt"
```

### Set up sops for Kubernetes

```bash
## Create a folder and a sops rule file
mkdir secrets

## add the public age key from the file "cat ~/.sops/sops_key.txt"
vi .sops.yaml
# creation_rules:
#   - path_regex: secrets/.*\.ya?ml$
#     encrypted_regex: '^(data|stringData|password|token|secret|ssh_keys)$'
#     age: age13kmzf9h8dzqj6casmj.....

# ---

## Secret Datei erstellen für das Deployment
vi secrets/forgejo-admin.sops.yaml

apiVersion: v1
kind: Secret
metadata:
    name: forgejo-admin-secret
    namespace: forgejo
type: Opaque
stringData:
    username: hth
    password: MySuperSecureP@$$w0rd!

# ---

## Verschlüsseln
sops -e -i secrets/forgejo-admin.sops.yaml

## Entschlüsseln
sops -d -i secrets/forgejo-admin.sops.yaml

## Secret in Kubernetes hochladen
sops -d secrets/forgejo-admin.sops.yaml | kubectl apply -f -

helm upgrade forgejo oci://code.forgejo.org/forgejo-helm/forgejo -n forgejo -f apps/forgejo/values.yaml
```
