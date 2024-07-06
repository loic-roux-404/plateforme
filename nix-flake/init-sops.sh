#!/usr/bin/env bash

sops_key=$(cat "$HOME/.ssh/id_ed25519.pub" | ssh-to-age)

cat <<EOF > ~/.sops.yaml
creation_rules:
- key_groups:
    - age:
    - "$sops_key"
    path_regex: "\\w\\.(yaml|json)$"
keys:
- $sops_key
EOF

SOPS_AGE_KEY=$(ssh-to-age -private-key < ~/.ssh/id_ed25519)
export SOPS_AGE_KEY
