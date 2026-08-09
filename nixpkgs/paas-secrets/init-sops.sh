#!/usr/bin/env bash

set -euo pipefail

SOPS_AGE_KEY=$(ssh-to-age -private-key < ~/.ssh/id_ed25519)
SOPS_AGE_RECIPIENTS=$(ssh-to-age < ~/.ssh/id_ed25519.pub)

export SOPS_AGE_KEY SOPS_AGE_RECIPIENTS
