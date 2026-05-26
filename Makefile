SHELL=/bin/bash

.PHONY: help all bootstrap export-ca-certs deploy-podinfo deploy-postgresql deploy-forgejo

help:
	@echo "Available targets:"
	@echo "  make all"
	@echo "  make bootstrap"
	@echo "  make export-ca-certs"
	@echo "  make deploy-podinfo"
	@echo "  make deploy-postgresql"
	@echo "  make deploy-forgejo"

all: bootstrap export-ca-certs deploy-podinfo deploy-postgresql deploy-forgejo

bootstrap:
	./scripts/bootstrap.sh

export-ca-certs:
	./scripts/export-ca-certs.sh

deploy-podinfo:
	kubectl apply -k ./apps/podinfo

deploy-postgresql:
	kubectl apply -k ./apps/postgresql
	sops -d ./secrets/forgejo-db-secret.yaml | kubectl apply -f -

deploy-forgejo: deploy-postgresql
    kubectl apply -f ./apps/forgejo/namespace.yml
	sops -d ./secrets/forgejo-admin-secret.yaml | kubectl apply -f -
	kubectl apply -f ./apps/forgejo/server-certificate.yaml
	helm upgrade --install forgejo oci://code.forgejo.org/forgejo-helm/forgejo -n forgejo -f ./apps/forgejo/values.yaml
