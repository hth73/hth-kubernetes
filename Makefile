SHELL := /bin/bash

export KUBECONFIG := $(HOME)/.kube/config

.NOTPARALLEL:

.PHONY: help all k3s k8s bootstrap-k3s bootstrap-k8s export-ca-certs deploy-podinfo deploy-headlamp deploy-argocd

# Standard-Setup
all: k8s

help:
	@echo "Available targets:"
	@echo "  make k3s              Install K3s setup"
	@echo "  make k8s              Install kubeadm Kubernetes setup"
	@echo "  make all              Same as make k8s"
	@echo "  make bootstrap-k3s    Bootstrap K3s infrastructure"
	@echo "  make bootstrap-k8s    Bootstrap kubeadm infrastructure"
	@echo "  make export-ca-certs  Export CA certificates"
	@echo "  make deploy-podinfo   Deploy Podinfo"
	@echo "  make deploy-headlamp  Deploy Headlamp"
	@echo "  make deploy-argocd    Install Argo CD"

k3s: bootstrap-k3s export-ca-certs deploy-podinfo deploy-headlamp deploy-argocd

k8s: bootstrap-k8s export-ca-certs deploy-podinfo deploy-headlamp deploy-argocd

bootstrap-k3s:
	./scripts/k3s/bootstrap.sh

bootstrap-k8s:
	./scripts/k8s/bootstrap.sh

export-ca-certs:
	./scripts/export-ca-certs.sh

deploy-podinfo:
	kubectl apply -k ./apps/podinfo

deploy-headlamp:
	kubectl apply -k ./infrastructure/dashboard

deploy-argocd:
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.5/manifests/install.yaml
	kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
	kubectl apply -k ./infrastructure/argocd
	kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
	kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=300s
