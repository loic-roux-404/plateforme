#!/usr/bin/env bash
# One-shot validation of the example wrapper as a fresh user would set it up.
# Throwaway age key + dummy secrets; builds the darwin closure and evals the
# NixOS image. Never switches the real system.
#
# Run from a nix environment with sops available:
#   nix shell nixpkgs#sops nixpkgs#age -c ./test.sh
set -euo pipefail

cd "$(dirname "$0")"
ROOT=$(git rev-parse --show-toplevel)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Function, not a var: a var would word-split and make "flakes" the command.
NIX() { nix --extra-experimental-features "nix-command flakes" "$@"; }

# 1. throwaway identity (fresh user model)
age-keygen -o "$WORK/age.key" >/dev/null
RECIPIENT=$(age-keygen -y "$WORK/age.key")
export SOPS_AGE_KEY_FILE="$WORK/age.key"

# 2. copy the template as a fresh user repo and wire the recipient
cp -r "$ROOT/example" "$WORK/secrets"
git -C "$WORK/secrets" init -q
# flakes in a git repo only see tracked files
git -C "$WORK/secrets" add -A
sed -i.bak "s/__YOUR_AGE_RECIPIENT__/$RECIPIENT/" "$WORK/secrets/.sops.yaml" && rm "$WORK/secrets/.sops.yaml.bak"
cp "$WORK/secrets/secrets-skeleton/darwin.yaml" "$WORK/secrets/darwin.yaml"
(cd "$WORK/secrets" && sops encrypt -i darwin.yaml)
git -C "$WORK/secrets" add -A

# 3. prove the file decrypts for the throwaway key
sops -d "$WORK/secrets/darwin.yaml" >/dev/null

# 4. build the darwin closure from this checkout (PLATFORM_DIR equivalent)
$NIX build --override-input plateforme "path:$ROOT" \
  "$WORK/secrets#darwinConfigurations.builder.system" --no-link \
  --print-out-paths

# 5. eval the NixOS qcow image standalone
$NIX eval --raw "$ROOT#nixosConfigurations.initial.config.formats.qcow" >/dev/null

echo "example OK"
