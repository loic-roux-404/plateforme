# Distribution: consuming plateforme from a wrapper repo

plateforme is the product: nix flake, terraform modules, docs, agent
definitions, and the `example/` template. All deployment orchestration lives
in a **private wrapper repo** (values + secrets only) initialized from
[example/](../example/). The wrapper drives everything through one script:
`paas`.

## Initialize a wrapper

```bash
mkdir my-wrapper && cd my-wrapper && git init
nix run github:loic-roux-404/plateforme#paas -- init .
```

`paas init` installs the packaged `example/` template: `paas` + `terragrunt/`
are refreshed on every run, everything else (flake.nix, Makefile, .sops.yaml,
skeletons) only when absent — an existing wrapper never loses its values.
Then follow [example/README.md](../example/README.md) steps 2-5 (age
recipient, identity, encrypted `darwin.yaml`/`local.yaml`, `make bootstrap`).

Wrapper layout after init:

```
├── flake.nix / flake.lock   # pin: the `plateforme` input drives EVERYTHING
├── Makefile                 # bootstrap / update / doctor + paas delegation (build, reset, tg)
├── paas                     # deployment entrypoint
├── terragrunt/              # units: cloud/local, network/local (paas/apps = milestone 2)
├── local.yaml / prod.yaml / darwin.yaml    # SOPS secrets (authored here)
├── result/                  # generated: built qcow2
└── .terragrunt/             # generated: state + module cache
```

## Pin / override contract

One lock (`flake.lock`, input `plateforme`) selects the plateforme revision
for the darwin bootstrap, the nix image builds, AND the terragrunt module
tree. Terraform fetches the modules itself — no local clone step.

| `PLATFORM_DIR` | nix ref | terragrunt source |
|---|---|---|
| unset (default) | `github:loic-roux-404/plateforme/<rev>` | `git::https://github.com/loic-roux-404/plateforme.git//<module>?ref=<rev>` |
| `/path/to/plateforme` | `path:/path/to/plateforme` | that working tree (local-path source) |

`paas` exports the pin as env vars (`PLATEFORME_REV`, `PLATEFORME_REF`) which
`terragrunt/root.hcl` reads — running terragrunt directly? Export them first
(the header comment in `root.hcl` shows the jq one-liner).

`make update` bumps the pin; bump only after a green `make bootstrap` +
`paas reset`. `path:` flakes see only **git-tracked** files — `git add` new
plateforme files before pointing `PLATFORM_DIR` at a working tree.

## `paas` reference

```
paas build [TARGET]     # NixOS qcow2 → result/nixos.qcow2
                        #   TARGET: initial (default) | deploy | initial-contabo | deploy-contabo
paas tg <layer> [args]  # terragrunt in terragrunt/<layer>, inside the plateforme
                        #   devShell (terraform, terragrunt, sops, SOPS_AGE_KEY)
                        #   e.g. paas tg cloud/local apply -auto-approve
paas doctor             # OK/FAIL gates (pin, sops key, image pin marker, libvirt,
                        #   dnsmasq, minio, pebble); non-zero exit on any FAIL
paas reset              # destroy cloud → build initial → cloud → network,
                        #   step logs in .agent/logs/<ts>-<step>.log
paas login              # kubectl OIDC setup from the paas layer output (milestone 2)
paas init <dest>        # copy paas + terragrunt/ into an existing wrapper repo
```

Makefile equivalents (same pin contract): `make build`, `make reset`,
`make doctor`, `make tg LAYER=cloud/local ARGS='apply -auto-approve'`.

Milestone 1 (cloud + network) is wired; `paas/` and `apps/` units follow the
same 4-line unit shape once local is green.

## Deploy loop

```bash
nix run ../#paas -- doctor
nix run ../#paas -- reset                     # or step by step: build → tg cloud/local → tg network/local
nix run ../#paas -- tg network/local output -json k3s_config    # kubeconfig
```

Failures: see the `paas-debug-loop` skill (per-layer gates, bounded-retry
protocol, `CLICK NEEDED:` browser fallback). Logs land in `.agent/logs/`.

## Contabo / production

Same contract, different inputs: `terragrunt/cloud/contabo` + `network/contabo`
units (milestone 2, after local is green), `prod.yaml` secrets, x86 targets
(`initial-contabo` / `deploy-contabo`, need the linux-builder VM — see AGENTS.md
"Linux builder VM networking").
