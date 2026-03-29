#!/usr/bin/env bash

set -euo pipefail

FLAKE="${1}"

nix path-info --derivation "${FLAKE}.config.system.build.toplevel" | jq --raw-input '{ "path": . }'
