# Podinfo Demo App

<img src="https://img.shields.io/badge/podinfo-326CE5?style=flat&logo=kubernetes&labelColor=ffffff&logoColor=326CE5" />

[Stefan Prodan - podinfo](https://github.com/stefanprodan/podinfo)

---

[Back to home](../../README.md)

---

## Beschreibung

Podinfo ist eine kleine Open-Source-Webanwendung in Go, die entwickelt wurde, um bewährte Verfahren für den Betrieb von Microservices in Kubernetes zu demonstrieren. Die von Stefan Prodan entwickelte Anwendung wird häufig von CNCF-Projekten wie Flux oder Flagger für End-to-End-Tests, technische Demonstrationen und Workshops verwendet.

Das Hauptziel bei diesem Deployment war es, die ersten TLS-Zertifikate mit cert-manager innerhalb des Kubernetes-Clusters zu testen.

Damit das Betriebssystem die ausgestellten Zertifikate korrekt validieren kann, mussten sowohl das Root-CA- als auch das Sub-CA-Zertifikat aus der cert-manager PKI in den lokalen `ca-certificates` Speicher importiert werden.

```bash
## Zertifikate aus Kubernetes exportieren
kubectl get secret htdom-root-ca-secret -n cert-manager -o jsonpath='{.data.tls\.crt}' | base64 --decode
kubectl get secret htdom-sub-ca-secret -n cert-manager -o jsonpath='{.data.tls\.crt}' | base64 --decode

## Zertifikate importieren
sudo cp htdom-root-ca.crt /usr/share/ca-certificates
sudo cp htdom-sub-ca.crt /usr/share/ca-certificates
sudo dpkg-reconfigure ca-certificates
```

Zusätzlich wurden beide Zertifikate in den lokalen Zertifikatsspeicher von Google Chrome importiert. Anschließend konnte die URL `https://podinfo.htdom.lan` innerhalb der Testumgebung ohne Zertifikatswarnungen aufgerufen werden.

```bash
## /etc/hosts
sudo vi /etc/hosts
# 192.168.56.10 podinfo.htdom.lan

curl -s https://podinfo.htdom.lan | jq '.'
{
  "hostname": "podinfo-84844b6fd4-jldwf",
  "version": "6.12.0",
  "revision": "a547e00b6cd16bf4017852205169f29f74a86452",
  "color": "#34577c",
  "logo": "https://raw.githubusercontent.com/stefanprodan/podinfo/gh-pages/cuddle_clap.gif",
  "message": "greetings from podinfo v6.12.0",
  "goos": "linux",
  "goarch": "amd64",
  "runtime": "go1.26.3",
  "num_goroutine": "6",
  "num_cpu": "2"
}
```
