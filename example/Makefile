SHELL:=/usr/bin/env bash
MAKEFLAGS += --no-builtin-rules --no-builtin-variables
VARIANT?=builder

# Dev-loop guard: point PLATFORM_DIR at a plateforme checkout to build its
# working tree instead of the lockfile pin. Unset (default) = pin.
# The wrapper lock is your last-known-good bootstrap; `make update` bumps it
# after a green `make bootstrap`.
#
#   make bootstrap                                    # lockfile pin
#   PLATFORM_DIR=../plateforme make bootstrap         # sibling checkout
PLATFORM_DIR?=
ifneq ($(strip $(PLATFORM_DIR)),)
ifeq ($(shell test -f $(PLATFORM_DIR)/flake.nix && echo yes),)
$(error PLATFORM_DIR="$(PLATFORM_DIR)" has no flake.nix — not a plateforme checkout)
endif
PAAS_OVERRIDE:=--override-input plateforme path:$(PLATFORM_DIR)
endif

.PHONY: bootstrap bootstrap-contabo update doctor

bootstrap:
	@nix --extra-experimental-features "nix-command flakes" \
	build $(PAAS_OVERRIDE) .#darwinConfigurations.$(VARIANT).system \
	&& sudo ./result/sw/bin/darwin-rebuild switch $(PAAS_OVERRIDE) --flake .#$(VARIANT)

bootstrap-contabo:
	@VARIANT=builder-x86 $(MAKE) bootstrap

# Bump the pinned plateforme rev. Run only after a green `make bootstrap`
# built from the working-tree override — keep the pin last-known-good.
update:
	@nix --extra-experimental-features "nix-command flakes" flake update plateforme

# Decrypt nothing, just prove your key can open darwin.yaml.
doctor:
	@sops filestatus darwin.yaml
	@echo "wrapper OK"
