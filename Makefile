SHELL := /bin/bash

# Keep Makefile targets and scripts on the same kubeconfig.
export KUBECONFIG := $(HOME)/.kube/config

.NOTPARALLEL: all

.PHONY: help all bootstrap export-ca-certs deploy-podinfo deploy-yelb deploy-todo deploy-headlamp deploy-argocd

help:
	@echo "Available targets:"
	@echo "  make all              Bootstrap infrastructure and deploy the retained apps"
	@echo "  make bootstrap        Install/configure Cilium, CoreDNS config, cert-manager,"
	@echo "                        Metrics Server, Traefik, and Todo/Yelb DB Secrets"
	@echo "  make export-ca-certs  Export Root/Sub-CA certificates to the workstation trust store"
	@echo "  make deploy-podinfo   Deploy Podinfo"
	@echo "  make deploy-yelb      Deploy Yelb"
	@echo "  make deploy-todo      Deploy Todo"
	@echo "  make deploy-headlamp  Deploy Headlamp dashboard"
	@echo "  make deploy-argocd    Install/configure Argo CD"

# These prerequisites are intentionally ordered for a normal `make all` run.
all: bootstrap export-ca-certs deploy-podinfo deploy-yelb deploy-todo deploy-headlamp deploy-argocd

bootstrap:
	./scripts/bootstrap.sh

export-ca-certs:
	./scripts/export-ca-certs.sh

deploy-podinfo:
	kubectl apply -k ./apps/podinfo

deploy-yelb:
	kubectl apply -k ./apps/yelb

deploy-todo:
	kubectl kustomize --load-restrictor LoadRestrictionsNone ./apps/todo | kubectl apply -f -

deploy-headlamp:
	kubectl apply -k ./infrastructure/dashboard

deploy-argocd:
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.5/manifests/install.yaml
	kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
	kubectl apply -k ./infrastructure/argocd
	kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
	kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=300s
