SHELL:=/usr/bin/env bash
MAKEFLAGS += --no-builtin-rules --no-builtin-variables

#### Nix

BUILDER_EXEC:=
NIXOS_CONFIG:=qcow

ifeq ($(shell uname -s),Darwin)
   BUILDER_EXEC:=NIX_CONF_DIR=$(PWD)/bootstrap nix develop .\#builder --command
endif

bootstrap:
	@$(BUILDER_EXEC) echo "Started build environment"

nixos-local:
	@$(BUILDER_EXEC) nix build .#nixosConfigurations.default --system aarch64-linux

trust-ca:
	@curl -k https://localhost:15000/intermediates/0 > /tmp/pebble.crt && \
      sudo security add-trusted-cert -d -r trustAsRoot -k /Library/Keychains/System.keychain /tmp/pebble.crt

#### Terraform

TERRAGRUNT_FILES := $(shell find terragrunt -type d -name '.*' -prune -o -name 'terragrunt.hcl' -exec dirname {} \;)

$(TERRAGRUNT_FILES):
	@echo "Running apply in $@ directory"
	@cd $@ && terragrunt apply -auto-approve

.PHONY: fmt bootstrap nixos-local trust-ca $(TERRAGRUNT_FILES)
