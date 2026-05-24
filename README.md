# Kubernetes Test Umgebung

<img src="https://img.shields.io/badge/VirtualBox-2F61B4?style=flat&logo=virtualbox&labelColor=ffffff&logoColor=2F61B4" /> <img src="https://img.shields.io/badge/Kubernetes-326CE5?style=flat&logo=kubernetes&labelColor=ffffff&logoColor=326CE5" /> 

---

### Inhaltsverzeichnis

* [Cert Manager](cert-manager/README.md)
* [Podinfo Anwendung](apps/podinfo/README.md)

---

## Beschreibung

Dieses Repository dokumentiert den Aufbau einer Kubernetes Testumgebung zu Lern- und Evaluierungszwecken.

Der Fokus hier liegt auf:
- Fedora CoreOS
- Kubernetes (k3s)
- Infrastructure Automation
- Cert-manager & TLS
- Traefik Ingress
- Multi Node Networking
- GitOps Grundlagen

Die Umgebung wurde vollständig automatisiert und basiert auf:<br>
Packer, Vagrant und Ansible

Das Kubernetes-Cluster besteht aus:
- 1 Control Plane Node
- 2 Worker Nodes

Ziel des Projekts ist es, praktische Erfahrungen mit Kubernetes, CoreOS, Container-Orchestrierung sowie automatisierter Infrastruktur-Provisionierung zu sammeln und typische Plattform-Komponenten schrittweise selbst aufzubauen.

Um Zugriff auf das Kubernetes Cluster zu bekommen, benötigt man vorher die Kubernetes Client Konfigurationsdatei, diese wird dann im lokalen Verzeichnis unter `~/.kube/config` abgelegt. 

```bash
## Kubernetes Client Konfigurationsdatei - Master Node
ssh core@192.168.56.10 -p 22
sudo cat /etc/rancher/k3s/k3s.yaml

apiVersion: v1
clusters:
- cluster:
    ...
    server: https://127.0.0.1:6443
  name: default
...

# ------------------------------

vi ~/.kube/config

apiVersion: v1
clusters:
- cluster:
    ...
    server: https://192.168.56.10:6443
  name: default
...
```

Danach kann man mit dem Tool `kubectl` oder `k9s` auf das Kubernetes Cluster zugreifen und die ersten Tests durchführen.

```bash
kubectl get nodes        
# NAME             STATUS   ROLES           AGE   VERSION
# coreos-master    Ready    control-plane   18h   v1.35.5+k3s1
# coreos-worker1   Ready    <none>          18h   v1.35.5+k3s1
# coreos-worker2   Ready    <none>          18h   v1.35.5+k3s1

kubectl get namespaces 
# NAME              STATUS   AGE
# default           Active   18h
# kube-node-lease   Active   18h
# kube-public       Active   18h
# kube-system       Active   18h

kubectl get services
# NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
# kubernetes   ClusterIP   10.43.0.1    <none>        443/TCP   18h

# nginx pod anlegen und auf 3 pods erweitern
kubectl create deployment nginx --image=nginx
kubectl scale deployment nginx --replicas=3

kubectl get pods                                    
# NAME                     READY   STATUS    RESTARTS      AGE
# nginx-56c45fd5ff-7764h   1/1     Running   1 (80m ago)   19h
# nginx-56c45fd5ff-mvfvx   1/1     Running   1 (80m ago)   19h
# nginx-56c45fd5ff-v8npb   1/1     Running   1 (18h ago)   19h

kubectl describe svc nginx                 
# Name:                     nginx
# Namespace:                default
# Labels:                   app=nginx
# Annotations:              <none>
# Selector:                 app=nginx
# Type:                     NodePort
# IP Family Policy:         SingleStack
# ...

kubectl expose deployment nginx --port=80 --type=NodePort

kubectl get svc                                          
# NAME         TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
# kubernetes   ClusterIP   10.43.0.1     <none>        443/TCP        19h
# nginx        NodePort    10.43.39.44   <none>        80:30413/TCP   15s

curl http://192.168.56.11:30413
# <!DOCTYPE html>
# <html>
# <head>
# <title>Welcome to nginx!</title>
# ...

kubectl exec -it deploy/nginx -- sh

hostname
# nginx-56c45fd5ff-v8npb

ls -la
# total 4
# ...
# lrwxrwxrwx.   1 root root    7 May  8 16:10 bin -> usr/bin
# ...

kubectl get deployment
kubectl delete deployment nginx
kubectl get deployment

kubectl get services
kubectl delete svc nginx
kubectl get services
```
