---
name: paas-debug-loop
description: >
  Zero-touch debug loop for the wrapper-driven plateforme deployment (the
  `paas` script / Makefile targets in the private wrapper repo). Covers
  preflight gates (`paas doctor`), per-layer verification after each apply
  (cloud → network → paas → apps), failure classification and bounded
  retries, and the browser-click fallback. Use when `paas reset` or
  `paas tg <layer>` fails,
  when bringing the local libvirt environment up, or when hardening the loop
  after any layer change.
metadata:
  version: "1.0.0"
  domain: deployment
  triggers: >
    paas reset, paas doctor, paas tg, paas build, .agent/logs, terragrunt
    destroy, cloud/local, network/local, kubeconfig fetch, nodes not Ready,
    CLICK NEEDED
  role: platform-engineer
  scope: operations
  output-format: code
---

## Preflight — `paas doctor`

Run before any apply. Gates (one per line, any FAIL → fix before proceeding):

- pin: `PLATFORM_DIR` points at a checkout with `flake.nix`, or the wrapper
  lock rev is readable (terragrunt sources `git::…?ref=<rev>` — terraform
  fetches the modules itself, no local clone)
- sops: your age key opens the wrapper's `local.yaml`
- image: `result/nixos.qcow2` exists and `.paas-image` pin marker matches the
  current pin
- daemons: libvirtd, virtlogd, dnsmasq loaded; `virsh -c qemu:///system` works
- ports: minio `:9000`, pebble `:14000` listening (local env only)
- x86/contabo builds additionally need the linux-builder VM reachable
  (`linux-builder-ip`) — not gated for the aarch64 local env

## Layer gates — after each apply

Verify in order; a failed gate stops the loop at that layer (never apply the
next layer on a broken one):

1. **cloud** (`paas tg cloud/local apply`): `virsh -c qemu:///system domstate
   <vm>` = running; VM ssh reachable.
2. **network** (`paas tg network/local apply`): kubeconfig output present
   (`paas tg network/local output -json k3s_config`), then
   `kubectl --context plateforme get nodes` → Ready; VM has the injected
   secrets (module outputs / ssh: `/home/<user>/secrets.yaml`).
3. **paas** (milestone 2): cert-manager pods Ready; dex ingress answers
   HTTP 200/302.
4. **apps** (milestone 2): the AGENTS.md post-apply checklist — pods `1/1`,
   helm release `deployed`, ingress code sane (200/302/401), credentials
   surfaced via `paas tg apps/local output -json <key>`.

## Failure protocol

1. Read the step log: `.agent/logs/<ts>-<step>.log` (written by `paas reset`;
   for manual runs re-run with `2>&1 | tee`).
2. Classify the error: network (ssh/dns/libvirt), secrets (sops key /
   recipient / missing key in local.yaml), provider (terraform state /
   provider schema), helm (release stuck, values), nix (build / flake ref —
   remember `path:` flakes see only git-tracked files).
3. Fix the root cause; retry the FAILED LAYER ONLY (layers are ordered —
   resume at the failure point, never re-apply earlier layers blindly).
4. Bounded retries: max 3 per error class. Every iteration goes to
   `.agent/scratchpad.md` per AGENTS.md (attempted / result / similarity /
   next approach must differ when similar).
5. After 3 failures or no progress in 5 iterations: stop, escalate to the
   operator with a minimal reproducer (exact command + shortest decisive
   error line + what you tried).

## Browser fallback (the only human step)

OAuth2 walls and UI checks: drive `mcp__chrome-devtools` first
(navigate / click / screenshot). If blocked (rights, captcha, login wall the
tools cannot pass), post exactly:

```
CLICK NEEDED: <URL> — <what to press>
```

and wait for the operator. Do not guess past a login wall.

## Pin sanity

`PLATFORM_DIR` set changes EVERYTHING (nix ref + tf sources). If terraform
wants to destroy/recreate unexpectedly mid-loop, first check the pin did not
change under you (a `make update` or different `PLATFORM_DIR` between runs
changes both the nix image and the module tree).
