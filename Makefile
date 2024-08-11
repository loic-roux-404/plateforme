SHELL:=/usr/bin/env bash
MAKEFLAGS += --no-builtin-rules --no-builtin-variables
TF_CMD:=apply -auto-approve
VARIANT=builder

#### Nix

BUILDER_EXEC:=
NIXOS_CONFIG:=qcow

ifeq ($(shell uname -s),Darwin)
   BUILDER_EXEC:=NIX_CONF_DIR=$(PWD)/bootstrap nix develop .\#builder --command
endif

bootstrap:
	@$(BUILDER_EXEC) echo "Started default build environment"

bootstrap-x86:
	@VARIANT=builder-x86 $(BUILDER_EXEC) echo "Started x86 environment"

nixos-local:
	@$(BUILDER_EXEC) nix build .#nixosConfigurations.default --system aarch64-linux

TERRAGRUNT_FILES:=$(shell find terragrunt -type d -name '.*' -prune -o -name 'terragrunt.hcl' -exec dirname {} \;)

$(TERRAGRUNT_FILES):
	@sudo chmod -fR 755 $@/.terragrunt-cache/ && sudo chmod -fR 755 result
	@cd $@ && terragrunt $(TF_CMD)

release-stable:
	@git tag nixos-stable -f && git push --tags --force

.PHONY: fmt bootstrap nixos-local trust-ca $(TERRAGRUNT_FILES)
