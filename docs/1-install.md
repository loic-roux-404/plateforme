# Introduction et installation

---

The objective of this tutorial is to allow you to create a PaaS (Platform as a service) on a small machine or on a personal server. A PaaS allows to deploy applications in microservices. This one will be based on [kubernetes](https://kubernetes.io/fr/) for the containerization and [kubeapps](https://developer.hashicorp.com/kubeapps) for the deployment interface.

The optics of this tooling will follow :

- the principle **of immutable infrastructure** with the idea of recreating rather than updating. Thus we will use ready linux iso to deploy the **kubernetes** / **kubeapps** platform directly on a server.

- The principle **infrastructure as code** (IaC) by keeping all the specification of our infrastructure in configurations and scripts. We will also use basic tests of our configurations.

For this we will use a technical base composed of :

- the [`k3s`](https://k3s.io/) tool which simplifies the installation of kubernetes on ARM machines while remaining compatible with classic X64 architectures. It provides by default pods (containers in execution) to include features often sought on this type of edge computing configuration (reverse proxy, DNS configuration ...)
- [Packer](https://www.packer.io/) to create iso images of linux machines
- [Ansible](https://www.ansible.com/) to provision this image
- [Terraform](https://www.terraform.io/) to control azure in an IaC way and to trigger all the PaaS implementation on it.

Translated with www.DeepL.com/Translator (free version)

## Installation de Docker

Docker architecture :

![docker architecture](https://docs.docker.com/engine/images/architecture.svg)

> Source documentation docker

et les couches des systèmes de conteneurisation docker et kubernetes :

![docker k8s architecture](images/kube-archi.png)

## Rancher as docker desktop replacement

[**Rancher**](https://rancherdesktop.io/) Download 1.6.2 (macOS) from [github release](https://github.com/rancher-sandbox/rancher-desktop/releases/tag/v1.6.2)

At first start configure rancher as follow :
- **Disable kubernetes**
-  **dockerd** as engine

Check command `docker` is available. If not add `~/.rd/bin` to `PATH` :

```bash
echo 'export PATH="$PATH:$HOME/.rd/bin"' >> ~/.zshrc
```

## Installation de vscode

- [Avec installer toutes plateformes](https://code.visualstudio.com/download)
- Homebrew sur mac `brew install --cask visual-studio-code`
- [Avec snap pour linux](https://snapcraft.io/code) sur linux

## Python environment

**Everything here is done with a `bash` or `zsh shell`**

**Conda** : [docs.conda.io](https://docs.conda.io/en/latest/miniconda.html). Run `.pkg` for mac.

> utilisez la ligne de commande ci-dessous pour l'installer
```bash
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -P /tmp
chmod +x /tmp/Miniconda3-latest-Linux-x86_64.sh
/tmp/Miniconda3-latest-Linux-x86_64.sh -p $HOME/miniconda
```

> Pour arm :
```bash
wget https://repo.anaconda.com/miniconda/Miniconda3-py39_4.12.0-Linux-aarch64.sh -P /tmp
chmod +x /tmp/Miniconda3-py39_4.12.0-Linux-aarch64.sh
/tmp/Miniconda3-py39_4.12.0-Linux-aarch64.sh -p $HOME/miniconda
```

Consent to agreements and licences in next prompts.

Then run `conda init zsh` (or `bash` if you prefer)

**Relancer votre shell pour appliquer** (commande `exec $SHELL`)

## Ansible playbook

Setup vault password in a file :

```bash
echo 'pass' > ~/.ansible/.vault
```

Then install requirements :

```bash
cd playbook
ansible-galaxy install -r requirements.yml
pip install -r requirements.txt
cd -
```

### Test kubeapps role with molecule :


Setup mac os networking with rancher :

```bash
cd playbook/roles/kubeapps
./scripts/setup_macos.sh
```

Recover ip subnet if needed (ex: 172.29.0.20) and edit `metallb_ip_range` accordingly :

```bash
docker network inspect k3snet | jq -r '.[0].IPAM.Config[0].Subnet' | awk -F. '{print $1"."$2}'
```

Setup dnsmasq to wildcard domain to localhost :

```bash
cd playbook/roles/kubeapps
./scripts/setup_dnsmasq.sh
```

```bash
molecule test
```

To open UI with https add pebble certificate to your truststore :

```bash
curl -k https://localhost:15000/intermediates/0 > ~/Downloads/pebble-ca.pem
sudo security add-trusted-cert -d -r trustAsRoot -k /Library/Keychains/System.keychain ~/Downloads/pebble-ca.pem
```

- [Dex](https://dex.k3s.test/.well-known/openid-configuration)
- [kubeapps](https://kubeapps.k3s.test/)

> Authentication with dex is not working over waypoint UI in localhost because of non trusted certificate.

Setup kubeapps inside cluster before getting token :

```bash
Run KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubeapps login -from-kubernetes"
```

Setup kubeapps login context outside cluster :

> You can use `waypoint.k3s.test:443` in a simple network network (VPN, Firewall, DnsMasq are probably going to gives you trouble)

```bash
export WAYPOINT_SERVER_TOKEN=token
waypoint context create \
    -server-addr='localhost:443' \
    -server-auth-token="$WAYPOINT_SERVER_TOKEN" \
    -server-require-auth=true \
    -server-tls-skip-verify=true \
    -set-default waypoint.k3s.test-ui

```

### Debug on rancher vm with a better network

```bash
rdctl shell
```

```bash
wget https://releases.hashicorp.com/waypoint/0.11.0/waypoint_0.11.0_linux_arm64.zip -O /tmp/waypoint.zip
sudo unzip /tmp/waypoint.zip -d /usr/local/bin/
rm /tmp/waypoint.zip
sudo chmod +x /usr/local/bin/waypoint
```

## Packer image

> In folder `packer/`

```bash
PACKER_LOG=0 PACKER_LOG_PATH=ubuntu-jammy.log packer build -var-file "$(uname -ms | tr " " "-")-host.hcl" -var-file=secrets.pkrvars.hcl ubuntu.pkr.hcl
```

> use `PACKER_LOG=1` for debug and `-on-error=ask`

**Simplified usage with makefile** :

```bash
make ubuntu-debug
```

> In debug mode you could need to do `ssh-keygen -f ~/.ssh/known_hosts -R [127.0.0.1]:2225` to delete old ssh trusted key for host

or for release :

```bash
make ubuntu
```

Release image manually :

```bash
git tag "ubuntu-jammy-$(git rev-parse --short HEAD)"
git push --tags
```

Open release from tag on [this link](https://github.com/loic-roux-404/k3s-paas/releases/new)

## Terraform

```bash
INSTANCE_ID=$(grep "contabo_instance" prod.tfvars | cut -d'=' -f2 | tr -d ' ' | tr -d \")
terraform import -var-file=prod.tfvars contabo_instance.paas_instance $INSTANCE_ID
terraform apply -auto-approve -var-file=prod.tfvars

```

Or maintained make command `make apply`
