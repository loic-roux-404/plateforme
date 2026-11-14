# Example: bootstrap the stack as a new user

The public plateforme flake builds the macOS control host (nix-darwin) and
the NixOS VM images, but takes **no secrets input**. Your secrets live in a
private wrapper repo that pins plateforme and injects your SOPS file at
build time — the [example/](../example/) directory in this repository is the
template for that wrapper.

Full walkthrough: [example/README.md](../example/README.md).

## Summary

```
your-dir/
├── plateforme/   # public clone (this repo)
└── secrets/      # copy of example/, your private wrapper repo
```

1. **Clone plateforme**, copy `example/` out to a sibling `secrets/` private
   repo (`git init`).
2. **Age key**: `ssh-to-age < ~/.ssh/id_ed25519.pub` → put the recipient in
   `secrets/.sops.yaml`.
3. **Identity**: set `user` / `githubUser` in `secrets/flake.nix`.
4. **Secrets**: `cp secrets-skeleton/darwin.yaml . && sops encrypt -i
   darwin.yaml` (dummy values bootstrap fine; the AI stack is disabled by
   default — see the README to re-enable it).
5. **macOS host**: `make bootstrap` in `secrets/`.
6. **NixOS image**: `nix develop && make build` in `plateforme/` →
   `result/nixos.qcow2`.
7. **Local env**: `make terragrunt/cloud/local` → `network/local` →
   `paas/local` → `apps/local`, then `make login`.

## Why a wrapper repo

- Secrets stay private: plateforme is the public product, the wrapper is the
  only place ciphertext lives. One commit there rotates a secret — no
  plateforme change.
- The pin (`flake.lock`) is your last-known-good bootstrap; `make update`
  bumps it only after a green `make bootstrap`.
- `PLATFORM_DIR=../plateforme make bootstrap` validates a plateforme working
  tree through the wrapper before you bump the pin.

## Validate the template

`example/test.sh` reproduces a fresh user (throwaway age key, dummy secrets)
and builds the darwin closure — no switch, safe to run anytime:

```bash
nix shell nixpkgs#sops nixpkgs#age -c ./example/test.sh
```
