#!/usr/bin/env bash

set -euo pipefail

# Point ./secrets at the pinned flake input (read-only store path).
# Terragrunt's find_in_parent_folders("secrets/<env>.yaml") uses it.
# The store path is substituted at build time by the `paas-secrets`
# derivation (nixpkgs/paas-secrets/default.nix) — see the @SECRETS_SRC@ token below.
if [ -e ./secrets ] && [ ! -L ./secrets ]; then
  echo "WARNING: ./secrets is not a symlink (old nested checkout?)."
  echo "Remove it after pushing all changes: rm -rf ./secrets"
else
  ln -sfn @SECRETS_SRC@ ./secrets
fi
