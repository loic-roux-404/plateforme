SHELL:=/usr/bin/env bash
MAKEFLAGS += --no-builtin-rules --no-builtin-variables

BUILDER_EXEC:=
ADD_CERT_CMD:=cp /tmp/pebble-ca.pem /etc/ssl/certs/pebble-ca.pem
ifeq ($(shell uname -s),Darwin)
   # set variable for Darwin
   BUILDER_EXEC:=nix develop .\#builder --extra-experimental-features flakes --extra-experimental-features nix-command --command
endif

bootstrap:
	@$(BUILDER_EXEC) echo "Started build environment"

build:
	@$(BUILDER_EXEC) nix build .#nixosConfigurations.x86_64-darwin.default --system x86_64-linux $(ARGS)

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

.PHONY: build bootstrap init $(TF_ROOT_DIRS) $(TF_ROOT_DIRS_DESTROY) $(TF_ROOT_DIRS_INIT)
