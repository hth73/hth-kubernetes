SHELL=/bin/bash

export KUBECONFIG := $(HOME)/.kube/master1

.PHONY: help all bootstrap export-ca-certs deploy-podinfo deploy-petclinic deploy-yelb deploy-forgejo deploy-headlamp deploy-argocd

help:
	@echo "Available targets:"
	@echo "  make all"
	@echo "  make bootstrap"
	@echo "  make export-ca-certs"
	@echo "  make deploy-podinfo"
	@echo "  make deploy-petclinic"
	@echo "  make deploy-yelb"
	@echo "  make deploy-forgejo"
	@echo "  make deploy-headlamp"
	@echo "  make deploy-argocd"

all: bootstrap export-ca-certs deploy-podinfo deploy-petclinic deploy-yelb deploy-forgejo deploy-headlamp deploy-argocd

bootstrap:
	./scripts/bootstrap.sh

export-ca-certs:
	./scripts/export-ca-certs.sh

deploy-podinfo:
	kubectl apply -k ./apps/podinfo

deploy-petclinic:
	kubectl apply -k ./apps/petclinic

deploy-yelb:
	kubectl apply -k ./apps/yelb

deploy-forgejo:
	kubectl apply -k ./apps/forgejo/db
	helm upgrade --install forgejo oci://code.forgejo.org/forgejo-helm/forgejo -n forgejo -f ./apps/forgejo/srv/values.yaml
	kubectl apply -f ./apps/forgejo/srv/server-certificate.yaml

deploy-headlamp:
	kubectl apply -k ./infrastructure/dashboard

deploy-argocd:
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.5/manifests/install.yaml
	kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
	kubectl apply -k ./infrastructure/argocd
	kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
	kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=300s
