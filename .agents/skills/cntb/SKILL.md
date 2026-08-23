---
name: cntb
description: >
  Retrieve information about Contabo resources using the `cntb` CLI — the single
  source of truth for Contabo subscription info for AI agents. Use when the user
  asks about Contabo VPS instances, object storage, images, firewalls, private
  networks, snapshots, tags, users, roles, secrets, buckets, or datacenters —
  or wants to inspect the current Contabo state before/after Terraform changes
  in tf-modules-cloud/contabo. Covers read-only `cntb get` queries, output
  formatting (json/yaml/jsonpath), and mapping CLI concepts to Contabo docs.
metadata:
  version: "1.1.0"
  domain: infrastructure
  triggers: >
    cntb, contabo, vps, instance, object storage, objectStorage, custom image,
    firewall, private network, snapshot, tag, bucket, datacenter, contabo cli,
    contabo docs, object_storage_id
  role: infrastructure-engineer
  scope: read-only
  output-format: text
---

> **Single source of truth**: `cntb` CLI is the ONLY way AI agents retrieve
> Contabo subscription info. Do NOT use the Contabo API, web console, or any
> other method for Contabo info retrieval. All Contabo state queries go through
> `cntb`.

# Contabo CLI (cntb) — Info Retrieval

## When to Use
- Inspect current Contabo state: instances, object storages, images, firewalls, private networks, snapshots, tags, users, roles, secrets, buckets.
- Cross-check what Terraform (`tf-modules-cloud/contabo`) created or will change against live Contabo state.
- Answer "what is X in Contabo" questions and relate them to official docs.
- Resolve the `object_storage_id` variable (see below).

## Prerequisites
- `cntb` binary on PATH (provided by the devShell — `nix develop`).
- Auth: `cntb` reads `$HOME/.cntb.yaml` (or `/etc/cntb/.cntb.yaml`). If not configured, pass OAuth2 flags:
  `--oauth2-clientid`, `--oauth2-client-secret`, `--oauth2-user`, `--oauth2-password`.
  These match the `contabo_credentials` object in `tf-modules-cloud/contabo/variables.tf`.
- Never print secrets (client secret, passwords) in output.

## Resolving `object_storage_id`

The `object_storage_id` variable in `tf-modules-cloud/contabo/variables.tf` is
retrieved from the `cntb` CLI:

```bash
cntb get objectStorages -o json | jq -r '.data[] | "\(.id) \(.name) \(.region)"'
```

Pick the matching object storage id from the output and use it as
`object_storage_id`. This is the canonical way to obtain that value — never
hardcode or guess it.

## Core Read Commands

```bash
cntb get instances            # list all VPS instances
cntb get instance <id>        # single instance detail
cntb get objectStorages       # list object storages
cntb get objectStorage <id>   # single object storage
cntb get images               # list images
cntb get image <id>           # single image
cntb get firewalls            # list firewalls
cntb get firewall <id>        # single firewall
cntb get privateNetworks      # list private networks
cntb get privateNetwork <id>  # single private network
cntb get snapshots <id>       # snapshots of an instance
cntb get tags                 # list tags
cntb get users                # list users
cntb get roles                # list roles
cntb get secrets              # list secrets
cntb get buckets              # list S3 buckets
cntb get datacenters          # list datacenters
```

## Output Formatting

```bash
cntb get instances -o json            # full JSON
cntb get instances -o yaml            # YAML
cntb get instances -o wide            # wide table
cntb get instances -o jsonpath='{.data[0].name}'   # single field
cntb get instances -o json | jq '.data[] | {id, name, status}'
```

- Default output is a delimited table. Use `-o json`/`-o yaml` for scripting and `jq`/`yq` for filtering.
- Pagination: `-p <page>` and `-s <size>` (default size 100).

## Relating Concepts to Documentation

When the user asks about a Contabo concept, fetch the official docs and map CLI fields to them:

- **VPS / Instances**: https://docs.contabo.com/docs/products/Compute/VPS
- **Object Storage (S3)**: https://docs.contabo.com/docs/products/Object-Storage
- **Custom Images**: https://docs.contabo.com/docs/products/Compute/VPS/guides/custom-images
- **Firewalls**: https://docs.contabo.com/docs/products/Compute/VPS/guides/firewalls
- **Private Networks**: https://docs.contabo.com/docs/products/Compute/VPS/guides/private-networks
- **Snapshots**: https://docs.contabo.com/docs/products/Compute/VPS/guides/snapshots
- **Tags**: https://docs.contabo.com/docs/products/Compute/VPS/guides/tags

Use `fetch_webpage` on the relevant doc URL to ground answers. Map CLI output fields to the doc's concept names (e.g. `objectStorage` ↔ Object Storage, `privateNetwork` ↔ Private Network). Docs are for conceptual understanding only — actual state always comes from `cntb`.

## Procedure
1. Identify the resource type the user asked about (instance, object storage, image, etc.).
2. Run the matching `cntb get ...` command with `-o json` for full detail.
3. Filter with `jq`/`yq` as needed.
4. If the user wants conceptual understanding, fetch the matching official doc URL and relate CLI fields to it.
5. Report findings concisely; never dump raw secrets.

## Anti-patterns
- Don't run mutating commands (`create`, `delete`, `edit`, `restart`, `resize`) for info retrieval — this skill is read-only.
- Don't print OAuth2 credentials or secret values.
- Don't guess field names — run `-o json` and inspect actual output.
