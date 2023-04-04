VAR_FILE?=prod.tfvars
SHELL:=/bin/bash

read_tfvar=$(shell grep $1 prod.tfvars | cut -d'=' -f2 | tr -d ' ' | tr -d \")

CLIENT_ID:=$(call read_tfvar,oauth2_client_id)
CLIENT_SECRET:=$(call read_tfvar,oauth2_client_secret)
API_USER:=$(call read_tfvar,oauth2_user)
API_PASSWORD:=$(call read_tfvar,oauth2_pass)
INSTANCE_ID:=$(call read_tfvar,contabo_instance)

.DEFAULT_GOAL := help

help:
	@echo "Contabo tf simple helpers"
	@echo "Instance setup $(INSTANCE_ID)"

setup_cntb:
	cntb config set-credentials --oauth2-clientid="$(CLIENT_ID)" \
		--oauth2-client-secret="$(CLIENT_SECRET)" --oauth2-user="$(API_USER)" \
		--oauth2-password="$(API_PASSWORD)"

destroy:
	terraform destroy -var-file=$(VAR_FILE) -auto-approve

# Run it if starting from empty infra
apply:
	$(MAKE) setup_cntb
	terraform import -var-file=$(VAR_FILE) contabo_instance.paas_instance $(INSTANCE_ID)
	terraform apply -var-file=$(VAR_FILE) -auto-approve

# Destroy and recreate contabo image and instance
update-force:
	terraform destroy -var-file=$(VAR_FILE) \
		-target=contabo_image.paas_instance_qcow2 -auto-approve
	terraform import -var-file=$(VAR_FILE) contabo_instance.paas_instance $(INSTANCE_ID)
	terraform apply -var-file=$(VAR_FILE) -auto-approve

read_tfvar:
	$(call read_tfvar contabo_instance)
