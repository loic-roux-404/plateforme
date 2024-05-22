SHELL:=/usr/bin/env bash
MAKEFLAGS += --no-builtin-rules --no-builtin-variables

BUILDER_EXEC:=

ifeq ($(shell uname -s),Darwin)
   BUILDER_EXEC:=NIX_CONF_DIR=$(PWD)/bootstrap nix develop .\#builder --command
endif

bootstrap:
	@$(BUILDER_EXEC) echo "Started build environment"

build:
	@$(BUILDER_EXEC) nix build .#nixosConfigurations.aarch64-darwin.default --system aarch64-linux $(ARGS)

build-x86:
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

.PHONY: build build-x86 bootstrap init $(TF_ROOT_DIRS) $(TF_ROOT_DIRS_DESTROY) $(TF_ROOT_DIRS_INIT)
