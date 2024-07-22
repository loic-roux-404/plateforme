# K3s PaaS

- [Documentation](https://loic-roux-404.github.io/k3s-paas/)
- [Original tutorial (FR)](https://github.com/esgi-lyon/paas-tutorial/blob/main/docs/index.md)

Compatibility Matrix :

| OS | Status |
| --- | --- |
| Darwin | OK |
| Linux | NO |

## New Nix system (beta)

### Setup (Darwin)

Nix installation :

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

echo '. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish' >> ~/.config/fish/config.fish
```

### Build

Set up nixos-darwin :

```bash
NIX_CONF_DIR=$PWD/bootstrap nix develop .#builder --command echo 
```

Build an image between available nixos configuration `contabo` and `qcow2` :

> Supported systems are `aarch64-linux`, `x86_64-linux`, `aarch64-darwin` and `x86_64-darwin`.
    
```bash
nix build .#nixosConfigurations.default --system aarch64-linux
```

On macOS, dnsmasq starts in background, you might need to force a refresh of the dns cache :

```bash
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

Also you will have to trust the CA :

```bash
make trust-ca
```

### Uninstall on Darwin:

> When builder environment not starting (no libvirtd.sock)

```bash
./result/sw/bin/darwin-uninstaller
```

## Terraform project secrets

You have to create a secrets file utilising following sops command :

```bash
sops secrets/prod.yaml
```

> **Note** : sops follow environment variables from default flake shell to encrypt files with the default `id_ed25519` ssh key.

### 1. Contabo (VPS)

**contabo_credentials** :

```yaml
contabo_credentials:
  oauth2_client_id: "client-id"
  oauth2_client_secret: "secret"
  oauth2_pass: "password!"
  oauth2_user: "mail@mail"

```

Seek for credentials in [API](https://my.contabo.com/api/details) 

**`contabo_instance` :**

```bash
cntb config set-credentials --oauth2-clientid id --oauth2-client-secret secret --oauth2-password "contabo-dashboard-pass"
cntb get instances
```

### 2. Gandi (domain)

- **`paas_base_domain`** : Order a domain on [gandi](https://www.gandi.net)
- **`gandi_token`** : Generate a Personal Access Token on [gandi organization](https://admin.gandi.net/organizations/)

> **Warn :** Delete `@` record for your domain on [gandi](https://admin.gandi.net/domain/)

### 3. Tailscale (SSH VPN)
**`tailscale_oauth_client`** : 
    - `id` : Register on tailscale and get key on [admin console](https://login.tailscale.com/admin/settings/keys)
    - `secret` : retrieve it during step above.

**`tailscale_trusted_device`** : Approve your device on tailscale with **`tailscale login`** and recover its tailscale hostname.

### 4. Github (Authentication & users)

**`github_token`** : https://github.com/settings/tokens and create a token with scopes `repo`, `user` and `admin`.
**`github_client_id`** : Create a new OAuth App.
**`github_client_secret`** : On new OAuth App ask for a new client secret.
**github_organization :** : Your github organization name.
**github_team :** : Your github team id.

### 5. Cert-manager (TLS)

**`cert_manager_email`** : a valid email to register on letsencrypt.

### Cloud (contabo)

```bash
make terragrunt/cloud/contabo
```

### Network (tailscale)

```bash
make terragrunt/network/contabo
```

### infra (k8s)

```bash
make terragrunt/paas/contabo
```

**Note** : Retrieve any config with :

```bash
make terragrunt/network/contabo TF_CMD='output -json k3s_config | yq -p json -o yaml'

```

### Install in local

Here is the command to set up the paas on a libvirt vm.

```bash
make terragrunt/cloud/local
make terragrunt/network/local
make terragrunt/paas/local
```

Then you have to do `make trust-ca` to trust paas internal CA on your system.

## Cheat Sheet

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
virsh -c qemu:///system undefine --nvram k3s-paas-master-0
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

### Kubectl

Set context :

```bash
kubectl config set-cluster default --server=http://k3s-paas-master-0:6443
kubectl config default test-cluster
```

See all pods :

```bash
kubectl get po -A
```

See any assets :

```bash
kubectl get all -A
```

### Release

```bash
git tag nixos-stable -f && gp --tags --force
```

### Contabo

Retrieve images :

```bash
cntb get images --imageType custom
```

Import existing image in terraform :

```bash
terraform import module.contabo.contabo_image.k3s_paas_master_image uuid
```

## Trouble shoot

#### Permissions errors on result directory in Terragrunt

```bash
rm -rf result
```
