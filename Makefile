SHELL:=/usr/bin/env bash
MAKEFLAGS += --no-builtin-rules --no-builtin-variables
TESTING_X86_URL=https://github.com/loic-roux-404/kube-paas/releases/download/nixos-testing/nixos.qcow2
TARGET?=initial

#### Nix

# Bootstrap (darwin switch) lives in the ../secrets wrapper Makefile — the
# only place with the real darwin.yaml. PLATFORM_DIR pins the wrapper build
# to THIS working tree instead of its flake.lock pin.
bootstrap bootstrap-contabo:
	@test -e secrets/Makefile || { echo "no secrets/ wrapper next to this repo — see docs/3-example.md" >&2; exit 1; }
	@$(MAKE) -C secrets PLATFORM_DIR=$(CURDIR) $@

nixos-local: build

# NixOS image build — output goes to IMAGE_DIR (default ./result), which is
# what terraform consumes as libvirt_qcow_source (see terragrunt/*/env.hcl).
# Keep the two in sync: env.hcl's find_in_parent_folders fails the apply if
# the image is not there.
IMAGE_DIR?=result

build:
	@nix build -o $(IMAGE_DIR) .#nixosConfigurations.$(TARGET).config.formats.qcow

pull-testing-x86:
	@rm -rf result && mkdir result
	@wget -q --show-progress -O result/nixos.qcow2 $(TESTING_X86_URL)

TERRAGRUNT_FILES:=$(shell find terragrunt -type d -name '.*' -prune -o -name 'terragrunt.hcl' -exec dirname {} \;)

# All terragrunt/<layer>/<env> targets delegate here. 1 is the natural
# way to pass any terragrunt subcommand; it defaults to a plain apply so the
# layer targets stay one-shot:
#
#   make terragrunt/cloud/local                    # apply -auto-approve
#   make terragrunt/network/contabo 1='plan'
#   make terragrunt/apps/local 1='destroy'   # any subcommand works
#   make terragrunt/network/contabo 1='output -json k3s_config | yq -p json -o yaml'
1?=apply -auto-approve

$(TERRAGRUNT_FILES):
	@terragrunt --working-dir $@ $(1)

ENV?=local

login:
	@terragrunt --working-dir terragrunt/paas/$(ENV) output -json oidc_login_setup_command_ops | jq -r .

cntb-login:
	@eval "$$(sops -d secrets/prod.yaml | yq -o shell '.contabo_credentials')" && \
	cntb config set-credentials \
		--oauth2-clientid "$$oauth2_client_id" \
		--oauth2-client-secret "$$oauth2_client_secret" \
		--oauth2-user "$$oauth2_user" \
		--oauth2-password "$$oauth2_pass"

skills-update:
	@npx skills update -y && npx skills add ./.agents/local-skills -a '*' -y

agents-update:
	@mkdir -p .github/agents .claude/agents
	@cp .agents/local-skills/agents/*.agent.md .github/agents/
	@cp .agents/local-skills/agents/*.agent.md .claude/agents/

.PHONY: fmt bootstrap nixos-local login cntb-login skills-update agents-update $(TERRAGRUNT_FILES)
