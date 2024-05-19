# K3s PaaS

- [Documentation](https://loic-roux-404.github.io/k3s-paas/)
- [Original tutorial (FR)](https://github.com/esgi-lyon/paas-tutorial/blob/main/docs/index.md)

Compatibility Matrix :

| OS | Status |
| --- | --- |
| Darwin | OK |
| Linux | missing builder tooling |

## New Nix system (beta)

### Setup (Darwin)

Nix installation :

```bash
sh <(curl -L https://nixos.org/nix/install)
```

### Build

One liner to set up darwin and build the system for aarch64-darwin :

```bash
nix develop .#builder --extra-experimental-features flakes \
    --extra-experimental-features nix-command \
    --command nix build .#nixosConfigurations.aarch64-darwin.default \
    --system aarch64-linux --refresh
```

> For next builds you can discard any `--extra-experimental-features` flags.
> --refresh is optional, it will force a rebuild of the system.

> **Note:** For local and staging env use --impure flag and NIX_SSL_CERT_FILE=nixos-darwin/certs/cert.pem to fetch urls.

For native linux simply run :
    
```bash
nix build .#nixosConfigurations.aarch64-darwin.default 
```

> Supported systems are `aarch64-linux`, `x86_64-linux`, `aarch64-darwin` and `x86_64-darwin`.

On macOS, dnsmasq starts in background, you might need to force a refresh of the dns cache :

```bash
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

### Uninstall on Darwin:

> When builder environment not starting (no libvirtd.sock)

```bash
./result/sw/bin/darwin-uninstaller
```

### Terraform local setup

Bootrap local vm :

```bash
terraform -chdir=libvirt init
terraform -chdir=libvirt apply -auto-approve
```

Setup k8s modules :

```bash
terraform init
terraform apply -auto-approve
```

## Quick links

## Cheat Sheet

## Recover kubeconfig

```bash
ssh zizou@localhost -p 2222 'sudo cat /etc/rancher/k3s/k3s.yaml' > ~/.kube/config
```

## Nix

See derivations of a build :

```bash
nix derivation show -r '.#nixosConfigurations.aarch64-darwin.default'
```

Filter derivations by name :

```bash
nix derivation show -r '.#nixosConfigurations.aarch64-darwin.default' | jq -r '.[] | select(.name | contains("cert-manager"))'
```

Debug flake :

```bash
nix --extra-experimental-features repl-flake repl '.#'
```

Free unused derivations :

```bash
nix-store --optimise
```

Repair nix store :

```bash
nix-store --verify --check-contents --repair
```

### Libvirt

Undefine pool :

```bash
virsh -c qemu:///system pool-undefine libvirt-pool-k3s-paas
```

Undefine vm to avoid conflicts :

```bash
virsh -c qemu:///system undefine --nvram vm1
```

Open console :

```bash
virsh -c qemu:///system console vm1
```

Exit with `Ctrl + +` or `Ctrl + ]` on linux.

> See [this SO thread](https://superuser.com/questions/637669/how-to-exit-a-virsh-console-connection#:~:text=ctrl%20%2B%20alt%20%2B%206%20(Mac)) if you keep struggling.

### Openssl

Generate a sha512crypt password :

```bash
openssl passwd -salt zizou -6 zizou420!
```

### Trust pebble cert

```bash
curl -k https://localhost:15000/intermediates/0 > /tmp/pebble-ca.pem
sudo security add-trusted-cert -d -r trustAsRoot -k /Library/Keychains/System.keychain /tmp/pebble-ca.pem
```

### SSH

Remove destroyed vm from ssh known hosts :

```bash
ssh-keygen -R [127.0.0.1]:2222
ssh-keygen -R [localhost]:2222
```

### Kubectl

See all pods :

```bash
kubectl get po -A
```
