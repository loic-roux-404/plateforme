SHELL:=/usr/bin/env bash

MAKEFLAGS += --no-builtin-rules --no-builtin-variables
# Consider adding a valid email in an environment variable TF_VAR_cert_manager_email
# of your shell profile
TF_VAR_cert_manager_email?=test@k3s.test
export TF_VAR_cert_manager_email

BUILDER_EXEC:=
ADD_CERT_CMD:=cp /tmp/pebble-ca.pem /etc/ssl/certs/pebble-ca.pem
ifeq ($(shell uname -s),Darwin)
   # set variable for Darwin
   BUILDER_EXEC:=nix develop .\#builder --extra-experimental-features flakes --extra-experimental-features nix-command --command
   ADD_CERT_CMD:=sudo security add-trusted-cert -d -r trustAsRoot -k /Library/Keychains/System.keychain /tmp/pebble-ca.pem
endif

export SSL_CERT_FILE=/tmp/pebble-ca.pem

init:
	@terraform -chdir=libvirt init -upgrade
	@terraform init -upgrade
	@terraform -chdir=oidc init -upgrade

bootstrap:
	@$(BUILDER_EXEC) echo "Started build environment"

build:
	@$(BUILDER_EXEC) nix build .#nixosConfigurations.aarch64-darwin.default --system aarch64-linux $(ARGS)

vm:
	@terraform -chdir=libvirt apply -auto-approve
	@ssh zizou@localhost -p 2222 'sudo cat /etc/rancher/k3s/k3s.yaml' > ~/.kube/config

vm-destroy:
	@terraform -chdir=libvirt destroy -auto-approve

infra:
	@terraform apply -auto-approve $(ARGS)

oidc:
	@terraform -chdir=oidc apply -auto-approve \
	  -var paas_token=$(shell terraform output paas_token) $(ARGS)

oidc-destroy:
	@terraform -chdir=oidc destroy -auto-approve \
	  -var paas_token=$(shell terraform output paas_token) $(ARGS)

infra-destroy:
	@terraform destroy -auto-approve $(ARGS)

trust-ca:
	@curl -k https://localhost:15000/intermediates/0 > /tmp/pebble-ca.pem
	@$(ADD_CERT_CMD)

.PHONY: init build vm vm-destroy infra oidc oidc-destroy infra-destroy trust-ca
