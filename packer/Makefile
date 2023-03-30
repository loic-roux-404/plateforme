UBUNTU_TPL:=ubuntu.pkr.hcl
SECRETS?=secrets.pkrvars.hcl
HOST_OS:=$(shell uname -ms | tr " " "-")
UBUNTU_RELEASE:=jammy

.DEFAULT_GOAL := ubuntu

ubuntu-debug:
	PACKER_LOG=1 PACKER_LOG_PATH=ubuntu-$(UBUNTU_RELEASE).log \
	packer build -on-error ask -var-file "$(HOST_OS)-host.hcl" \
		-var-file=$(SECRETS) $(UBUNTU_TPL)

ubuntu:
	packer build -var-file "$(HOST_OS)-host.hcl" \
		-var-file=$(SECRETS) $(UBUNTU_TPL)

ubuntu-console:
	packer console -var-file "$(HOST_OS)-host.hcl" \
		-var-file=$(SECRETS) $(UBUNTU_TPL)

clean:
	rm -rf ubuntu-$(UBUNTU_RELEASE).log

