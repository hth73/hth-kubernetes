SHELL=/bin/bash

export KUBECONFIG := $(HOME)/.kube/master1

.PHONY: help all bootstrap export-ca-certs deploy-podinfo deploy-petclinic deploy-yelb deploy-forgejo

help:
	@echo "Available targets:"
	@echo "  make all"
	@echo "  make bootstrap"
	@echo "  make export-ca-certs"
	@echo "  make deploy-podinfo"
	@echo "  make deploy-petclinic"
	@echo "  make deploy-yelb"
	@echo "  make deploy-forgejo"

all: bootstrap export-ca-certs deploy-podinfo deploy-petclinic deploy-yelb deploy-forgejo

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
