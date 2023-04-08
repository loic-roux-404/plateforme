VAR_FILE?=prod.tfvars
SHELL:=/bin/bash

read_tfvar=$(shell grep $1 prod.tfvars | cut -d'=' -f2 | tr -d ' ' | tr -d \")

CLIENT_ID:=$(call read_tfvar,oauth2_client_id)
CLIENT_SECRET:=$(call read_tfvar,oauth2_client_secret)
API_USER:=$(call read_tfvar,oauth2_user)
API_PASSWORD:=$(call read_tfvar,oauth2_pass)
INSTANCE_ID:=$(call read_tfvar,contabo_instance)

TAILSCALE_KEY:=$(call read_tfvar,tailscale_key)

.DEFAULT_GOAL := help

help:
	@echo "Contabo tf simple helpers"
	@echo "Apply infra on $(INSTANCE_ID) :"
	@echo "  make apply"
	@echo "Debug contabo with cli :"
	@echo "  make setup_cntb"
	@echo "Setup ssh"
	@echo "  make setup_ssh"

setup_cntb:
	cntb config set-credentials --oauth2-clientid="$(CLIENT_ID)" \
		--oauth2-client-secret="$(CLIENT_SECRET)" --oauth2-user="$(API_USER)" \
		--oauth2-password="$(API_PASSWORD)"

# Run it if starting from empty infra
apply:
	terraform apply -var-file=$(VAR_FILE) -auto-approve

setup_ssh:
	sudo tailscale up --authkey=$(TAILSCALE_KEY) --ssh
