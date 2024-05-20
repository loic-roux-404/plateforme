SHELL:=/usr/bin/env bash

MAKEFLAGS += --no-builtin-rules --no-builtin-variables
# Consider adding a valid email in an environment variable TF_VAR_cert_manager_email
# of your shell profile
TF_VAR_cert_manager_email?=test@k3s.test
export TF_VAR_cert_manager_email
# Validate nix localhost non secure connection

BUILDER_EXEC:=
ADD_CERT_CMD:=cp /tmp/pebble-ca.pem /etc/ssl/certs/pebble-ca.pem
ifeq ($(shell uname -s),Darwin)
   # set variable for Darwin
   BUILDER_EXEC:=nix develop .\#builder --extra-experimental-features flakes --extra-experimental-features nix-command --command
   ADD_CERT_CMD:=sudo security add-trusted-cert -d -r trustAsRoot -k /Library/Keychains/System.keychain /tmp/pebble-ca.pem
endif

bootstrap:
	@$(BUILDER_EXEC) echo "Started build environment"

build:
	@$(BUILDER_EXEC) nix build .#nixosConfigurations.aarch64-darwin.default --system aarch64-linux $(ARGS)

#### Terraform

TF_ROOT_DIRS := $(wildcard tf-root-*) .
TF_ROOT_DIRS_DESTROY:=$(addsuffix -destroy, $(TF_ROOT_DIRS))
TF_ROOT_DIRS_INIT:=$(addsuffix -init, $(TF_ROOT_DIRS))

init: $(TF_ROOT_DIRS_INIT)

$(TF_ROOT_DIRS_INIT):
	@$(eval DIR:=$(subst -init,,$@))
	terraform -chdir=$(DIR) init -upgrade $(ARGS)

$(TF_ROOT_DIRS):
	@terraform -chdir=$@ apply -compact-warnings -auto-approve $(ARGS)

$(TF_ROOT_DIRS_DESTROY):
	@$(eval DIR:=$(subst -destroy,,$@))
	@terraform -chdir=$(DIR) destroy -auto-approve $(ARGS)

trust-ca:
	@curl -k https://localhost:15000/intermediates/0 > /tmp/pebble-ca.pem
	@$(ADD_CERT_CMD)

.PHONY: build bootstrap init $(TF_ROOT_DIRS) $(TF_ROOT_DIRS_DESTROY) $(TF_ROOT_DIRS_INIT) trust-ca
