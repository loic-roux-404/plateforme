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

build:
	@nix build .#nixosConfigurations.$(NIXOS_CONFIG) --system aarch64-linux $(ARGS)

#### Terraform

TF_ROOT_DIRS_FMT:=$(addsuffix -fmt,$(TF_ROOT_DIRS))
TF_ROOT_DIRS_VALIDATE:=$(addsuffix -validate,$(TF_ROOT_DIRS))

init: $(TF_ROOT_DIRS_INIT)

fmt: $(TF_ROOT_DIRS_FMT)

$(TF_ROOT_DIRS_FMT):
	@$(eval DIR:=$(subst -fmt,,$@))
	terraform -chdir=$(DIR) fmt $(ARGS)

validate: $(TF_ROOT_DIRS_VALIDATE)

$(TF_ROOT_DIRS_VALIDATE):
	@$(eval DIR:=$(subst -validate,,$@))
	terraform -chdir=$(DIR) validate -no-color $(ARGS)

trust-ca:
	@curl -k https://localhost:15000/intermediates/0 > /tmp/pebble.crt && \
      sudo security add-trusted-cert -d -r trustAsRoot -k /Library/Keychains/System.keychain /tmp/pebble.crt

.PHONY: fmt validate build build-x86 bootstrap init trust-ca \
  $(TF_ROOT_DIRS_FMT) $(TF_ROOT_DIRS_VALIDATE)
