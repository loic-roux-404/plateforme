---
name: sops-secrets-platform
description: >
  SOPS + age secret management as practiced in loic-roux-404/plateforme.
  Covers ssh-to-age key derivation, devShell key export, sops_decrypt_file()
  in Terragrunt, per-VM re-encryption with two recipients (operator + VM host key),
  and the tf-modules-nix/deploy secret upload pattern.
  Use when creating or rotating secrets, diagnosing decryption failures,
  adding a new secret key, or understanding the recipient model.
metadata:
  version: "1.0.0"
  domain: secrets
  triggers: >
    sops, sops_decrypt_file, SOPS_AGE_KEY, SOPS_AGE_RECIPIENTS, ssh-to-age,
    secrets/prod.yaml, secrets/local.yaml, age, sops-nix, nixos_transient_secrets,
    retrieve-vm-age-key.sh, key-to-age.sh
  role: platform-engineer
  scope: security
  output-format: code
---

## Key Derivation Model

The project uses a **single operator key** derived from `~/.ssh/id_ed25519`:

```bash
# Executed automatically in nix devShell (nix-flake/init-sops.sh)
SOPS_AGE_KEY=$(ssh-to-age -private-key < ~/.ssh/id_ed25519)
SOPS_AGE_RECIPIENTS=$(ssh-to-age < ~/.ssh/id_ed25519.pub)
export SOPS_AGE_KEY SOPS_AGE_RECIPIENTS
```

This means:
- SOPS only works inside `nix develop` (or after manually sourcing init-sops.sh)
- Key rotation requires re-encrypting all secret files
- There is no backup recipient — if `id_ed25519` is lost, all secrets are unrecoverable

## Creating/Editing Secrets

```bash
# Must be inside nix develop
nix develop
sops secrets/prod.yaml    # creates or edits
sops secrets/local.yaml
```

## Secret Structure (from README)

```yaml
contabo_credentials:
  oauth2_client_id: ""
  oauth2_client_secret: ""
  oauth2_pass: ""
  oauth2_user: ""
paas_base_domain: ""
gandi_token: ""
github_username: ""
github_token: ""
github_client_id: ""
github_client_secret: ""
github_organization: ""
github_team: ""
github_apps_team: ""
cert_manager_email: ""
```

## VM Secret Re-encryption (tf-modules-nix/deploy)

For each NixOS VM, the deploy module:
1. Retrieves the VM's SSH host key and converts it to an age recipient
2. Generates a new ED25519 key pair for the VM (stored as `<node_id>.pub`)
3. Encrypts `nixos_transient_secrets` YAML with **two recipients**: the VM host key + the VM identity key
4. Uploads the encrypted file to `~/secrets.yaml` on the VM
5. sops-nix (NixOS module) decrypts at activation time

This means each VM has its own encrypted secret file — secrets are not shared across VMs.

## Missing: .sops.yaml

**There is no `.sops.yaml` in the repo.** This is a gap.
Without it, `sops` selects recipients from environment variables only.
Recommended addition:
```yaml
creation_rules:
  - path_regex: secrets/local\.yaml$
    age: >-
      <operator-age-pubkey>
  - path_regex: secrets/prod\.yaml$
    age: >-
      <operator-age-pubkey>,<backup-age-pubkey>
```

## Operational Risk

If `id_ed25519` is rotated:
1. Derive new age key: `ssh-to-age < ~/.ssh/id_ed25519_new.pub`
2. Re-key all secret files: `sops updatekeys secrets/*.yaml`
3. Update `.sops.yaml` (once created) with new pubkey
