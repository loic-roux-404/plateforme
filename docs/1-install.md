# Introduction et installation

---

L'objectif de ce tutoriel est de vous permettre de créer sur une petite machine ou sur un serveur personnel un PaaS (Platform as a service). Un PaaS permet de déployer des applications en microservices. Celui-ci sera basé sur [kubernetes](https://kubernetes.io/fr/) pour la conteneurisation et [kubeapps](https://developer.hashicorp.com/kubeapps) pour l'interface de déploiement.

L'optique de cet outillage suivra :

- le principe **d'immutable infrastructure** avec l'idée de recréer plutôt que de mettre à jour. Ainsi nous aurons recour à des iso linux déjà prêt pour déployer la plateforme **kubernetes** / **kubeapps** directement sur un serveur.

- Le principe **d'infrastructure as code** (IaC) en gardant toutes la spécification de notre infrastructure dans des configurations et scripts. On utilisera également des tests basiques de nos configurations.

Pour cela nous ferons appel à un socle technique composé de :

- l'outil [`k3s`](https://k3s.io/) qui simplifie l'installation de kubernetes sur des machines ARM tout en restant compatible avec les architectures classiques X64. Il fourni par défaut des pods (containers en execution) pour inclure des fonctionnalités souvent recherchés sur ce type de configuration edge computing. (reverse proxy, configuration DNS...)
- [Packer](https://www.packer.io/) pour créer des images iso de machine linux
- [Ansible](https://www.ansible.com/) pour provisioner cette image
- [Terraform](https://www.terraform.io/) pour contrôler azure de manière IaC et de déclencher toute la mise en place du PaaS dessus.

## Installation de Docker

Pour rappel l'architecture de base de docker :

![docker architecture](https://docs.docker.com/engine/images/architecture.svg)

> Source documentation docker

et les couches des systèmes de conteneurisation docker et kubernetes :

![docker k8s architecture](images/kube-archi.png)

## Rancher comme alternative à docker desktop

[**Rancher**](https://rancherdesktop.io/) l'alternative mieux configurée et sans soucis de license à docker desktop. Il est portable sur windows et mac et nous permet d'avoir une expérience docker complète et fonctionnelle sur notre machine.

Dans les choix proposés dans la mise en place :
- **Décocher kubernetes**
- Choisissez **dockerd** comme moteur de conteneurisation

Vérifier que vous avez bien la commande `docker` disponible sinon ajouter `~/.rd/bin` à votre `PATH` :

```bash
echo 'export PATH="$PATH:$HOME/.rd/bin"' >> ~/.zshrc
```

## Installation de l'environnement python

**Maintenant tout ce que nous allons faire se trouve dans la ligne de commande sur un shell `bash` ou `zsh`**

**Conda** : [docs.conda.io](https://docs.conda.io/en/latest/miniconda.html). Installer simplement avec le setup `.pkg` pour mac.

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

Veillez à bien accepter toutes les propositions (licence terms, initialize Miniconda3).

Puis lancer `conda init zsh` (ou `bash` si vous préférez)

**Relancer votre shell pour appliquer** (commande `exec $SHELL`)

## Installation de vscode

- [Avec installer toutes plateformes](https://code.visualstudio.com/download)
- Homebrew sur mac `brew install --cask visual-studio-code`
- [Avec snap pour linux](https://snapcraft.io/code) sur linux

## Ansible playbook

```bash
cd playbook
ansible-galaxy install -r requirements.yml
pip install -r requirements.txt
cd -
```

Test kubeapps role :

```bash
cd playbook/roles/kubeapps
./scripts/setup_dnsmasq.sh
molecule test
```

To open UI with https add pebbel certificate to your truststore :

```bash
curl -k https://localhost:15000/roots/0 > ~/Downloads/pebble-ca.pem
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ~/Downloads/pebble-ca.pem
```

- [Dex](https://dex.k3s.test/.well-known/openid-configuration)
- [Epinio](https://epinio.k3s.test/)


## Setup Github app


Go to your `Profile > Developer Settings > Oauth Apps > New Oauth App`
- Name: "Whatever"
- Homepage: "https://auth.myepiniocluster.com",
- Authorization callback URL: "https://auth.myepiniocluster.com/callback"

Then take note of the ClientID and the ClientSecret.

With those you need to edit the config.yaml inside the `dex-config`.

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
