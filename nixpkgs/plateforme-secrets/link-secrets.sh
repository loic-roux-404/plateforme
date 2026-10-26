#!/usr/bin/env bash

set -euo pipefail

if [ ! -d secrets/.git ]; then
  echo "WARNING: ../secrets missing or not a git checkout — cannot link."
  echo "Clone it beside plateforme:"
  echo "  git clone git@github.com:org/secrets.git ../secrets"
fi
