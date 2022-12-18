#!/usr/bin/env bash

cd /playbook || exit 1

INVENTORY=$(find . -name "packer-provisioner-ansible-local*" | head -1)

sudo ansible-playbook -i "$INVENTORY" \
  --vault-password-file .vault \
  --tag kubeapps --extra-vars "\
-o 'IdentitiesOnly=yes' \
dex_hostname=$1 kubeapps_hostname=$2" \
  -c local site.yaml

cd - || exit 1
