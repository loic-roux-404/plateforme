# Paas Tutorial

L'objectif de ce tutoriel est de vous permettre de créer sur une petite machine ou sur un serveur personnel un PaaS (Platform as a service) vous permettant de déployer des applications en microservices. Celui-ci sera basé sur [kubernetes]() pour la conteneurisation et [Openshift]() pour l'interface et les automatisation autour.

L'optique de cet outillage suivra :
- le principle **d'immutable infrastructure** avec l'idée de recréer plutôt que de mettre à jour. Ainsi nous aurons recour à des iso linux déjà prêt pour déployer la plateforme **kubernetes** / **openshift** directement sur un serveur.

- Le principe **d'infrastructure as code** en gardant toutes la spécification de notre infrastructure dans des configurations et scripts.

Pour cela nous ferons appel à 
- l'outil [`k3s`](https://k3s.io/) qui simplifie l'installation de kubernetes sur des machines ARM tout en restant compatible avec les architectures classiques X64.
- ¨Packer pour créer des images iso de machine linux
- Ansible pour provisioner cette image
- Azure pour nous founir des serveurs accessible en ssh sur lequels nous pourrons mettre en ligne

## Requis

> Ce tutoriel est dédié à Linux et Mac
> Pour utilisateurs de windows il faut un [**WSL**](https://learn.microsoft.com/fr-fr/windows/wsl/install)

- Docker [docker.com](htts://docker.com)

- Conda : [docs.conda.io](https://docs.conda.io/en/latest/miniconda.html)

Recommandations:
- extension vscode: `redhat.ansible`, `donjayamanne.python-extension-pack`

> **Warning** Exotic shells like fish are not recommanded for molecule testing

# I/ Créer la machine virtuelle servant de cluster

## Un iso pour Azure

## 1. Le playbook ansible

L'objectif d'ansible de est de déployer des configurations et des outils sur des machines. A l'aide d'un format de configuration simple
proche de l'algorithmie nous pourrons amener tous les outils indispensable à la création de notre PaaS.

### A. Installer ansible

Ansible est un outil dépendant de l'écosystème python. Pour simplifier la gestion des dépendances 
qui risquent de faire conflit avec d'autres installations
de python, nous allons utiliser `miniconda`.


On initialise un environnement virtuel pyrhon avec sa propre version de **python 3.10** et les dépendences ansible et molecule. Ainsi nos dépendences n'entrent pas en conflit avec d'autres non compatibles installé ailleur.

> Molecule est l'outil qui va nous permettre de vérifier que notre playbook fonctionne. Nous avons donc besoin de **docker** installé sur la machine.

// TODO REMOVE
> WARNING : une mise à jour est en cour de développement sur molecule afin de s'adapter à une nouveauté de docker-desktop. Pour activer la fonctionnalité de manière forcée nous devons renseigné la ligne `"default-cgroupns-mode": "host"` dans **Docker > Préférences > Docker Engine**

```bash
conda create -n playbook-paas python=3.10
conda activate playbook-paas
pip install pip install molecule[vagrant]
```

Vérifier que tous fonctionne avec `ansible --version`.

Vous devriez avoir `ansible [core 2.13.4]` dans le retour

### **Bonus** pour faire fonctionner l'extension VsCode ansible

> Vscode : .vscode/settings.json
> Remplacez bien le chemin avec le résultat de cette commande `which python`
```json
{
    "ansible.python.interpreterPath": "<User-Path>/mambaforge/envs/playbook-paas/bin/python"
}
```

### B. Playbook

Nous allons créer un playbook ansible qui va appeler plusieurs rôles ansible.
Il s'agit d'un projet chargé de lancer plusieurs roles différents sur des machines disponibles sur le réseau via **ssh**. (localhost par exemple peut être provisioné)

> Nous allons suivre l'alternative-directory-layout recommandé par cette [documentation](https://docs.ansible.com/ansible/latest/user_guide/sample_setup.html#alternative-directory-layout)

Voici la suite complète de commande pour créer la structure du playbook.

```bash

mkdir -p inventories/k8s-paas/group_vars
touch inventories/k8s-paas/hosts
touch inventories/k8s-paas/group_vars/all.yaml

touch site.yml
touch requirements.yaml

mkdir roles/
echo "roles" >> .gitignore
```

Ensuite dans `requirements.yaml` on importe les roles que l'on utilise en dépendances.

> Ansible galaxy est le gestionnaire de paquet pour importer des rôles et des collections ansible dans un playbook.

> [playbook/requirements.yaml](playbook/requirements.yaml)
```yaml
---
roles: 
    - src: xanmanning.k3s

collections:
    - name: community.general
    - name: community.docker
      version: 3.0.0-a2
    - name: kubernetes.core
```

Les **collections** vont servir à ajouter des fonctionnalités à ansible et ses directives de tâches. Ici on ajoute des fonctionnalités pour manipuler facilement les commandes docker et kubernetes.

Les **roles** correspondent à des suites de tâches qui vont installer et configurer un outil sur une machine. Ici on utilisera un [role k3s](https://github.com/PyratLabs/ansible-role-k3s) qui s'occupe de configurer en fonction de nos paramètre le cluster k3s.

> K3s n'utilise pas docker mais containerd pour utiliser les focntionnalités de container linux.

Pour installer ces requirements maintenant on lance dans le dossier `playbook/` :

```bash
ansible-galaxy install -r requirements.yaml
```

Normalement tous est installé correctement et prêt à l'emploi

### C. Initialiser le role qui installe kubeapps

Pour suivre la convention d'ansible nous allons procédé en créant un role interne à notre projet. L'objectif sera d'installer [kubeapps](https://github.com/vmware-tanzu/kubeapps) l'outil qui nous permettra de déployer les containers de nos applications et leur dépendances.

Dans le dossier `playbook` faites donc :

```bash
mkdir roles
cd roles
ansible-galaxy init kubeapps
cd kubeapps
# Créer un scénario de test par défaut
molecule init scenario -d docker default
```

Vous devriez obtenir cette structure dans le nouveau dossier `playbook/` :

```
README.md 
defaults/
files/     
handlers/
molecule/default
meta/      
tasks/     
templates/ 
tests/    
vars/
```

Voici ce que va être rendu comme structure de [**role**](https://docs.ansible.com/ansible/latest/user_guide/playbooks_reuse_roles.html).

Nous allons ensuite mettre à jour les métadonnées ansible galaxy avec notamment la dépendance kubernetes (rôle)

> Ligne 50 de [playbook/roles/kubeapps/meta/main.yml](playbook/roles/kubeapps/meta/main.yml)
```yaml
dependencies:
    - src: geerlingguy.kubernetes
```

Ensuite vous devez obligatoirement définir ces informations sur les metas du rôles:

> [playbook/roles/role-kubeapps/meta/main.yml](playbook/roles/role-kubeapps/meta/main.yml)
```yaml
galaxy_info:
  author: loic-roux-404
  namespace: paas_tutorial
  description: kubeapps deployment
  role_name: kubeapps
```

Le rôle kubernetes se lancera donc directement avant les tâches de celui de kubeapps.

### D. Premiers tests sur notre playbook

Nous allons d'abord définir l'utilisaton d'une distribution ubuntu pour installer nos outils. Pour les tests en local nous faisons donc du docker in docker ce qui impose quelques difficulés de test parfois et des configurations particulières.

> [playbook/roles/kubeapps/molecule/default/molecule.yml](playbook/roles/kubeapps/molecule/default/molecule.yml)
```yaml
---
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: instance
    image: geerlingguy/docker-${MOLECULE_DISTRO:-ubuntu2004}-ansible:latest
    command: ${MOLECULE_DOCKER_COMMAND:-""}
    privileged: true
    pre_build_image: true
    tty: true
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
      - /var/lib/docker
    networks:
      - name: k3snet

provisioner:
  name: ansible
verifier:
  name: ansible


```

Le playbook de test va ensuite nous permettre de vérifier la bonne execution du rôle et de ses dépendances.

> [playbook/roles/kubeapps/molecule/default/converge.yml](playbook/roles/kubeapps/molecule/default/converge.yml)
```yaml
---
- name: Converge
  hosts: all
  become: true
  vars:
    molecule_is_test: true
    k3s_build_cluster: false
  roles:
    - role: "{{ lookup('env', 'MOLECULE_PROJECT_DIRECTORY') | basename }}"

  pre_tasks:
    - name: Update apt cache.
      apt: update_cache=true cache_valid_time=600
      when: ansible_os_family == 'Debian'

    - name: Ensure test dependencies are installed (Debian).
      package: 
        name: [iproute2,gpg-agent]
        state: present
      when: ansible_os_family == 'Debian'

    - name: Gather facts.
      action: setup

```

Lancer le premier test avec 


```bash
molecule test
```

Vous pouvez aussi lancer `molecule test --destroy never` pour ensuite garder le container et debugger l'état du système après le provision ansible avec `docker exec -it "hash-container obtenu via docker ps" sh`

> Tips : En cas d'erreur `export ANSIBLE_STDOUT_CALLBACK=yaml` avant de lancer `molecule test` pour avoir un meilleur rendu de la possible erreur.

### E. Utiliser le rôle dans un playbook 

Nous allons créer le fichier `site.yaml` (dans le dossier `playbook/`) qui va se charger avec la commande `ansible-playbook` de lancer les rôles dans le bon ordre sur les machines.


> playbook/site.yaml
```yaml
---
- hosts: k8s-paas
  gather_facts: True
  become: True
  become_user: root
  roles:
    - role: roles/kubeapps

```

## 2. Créer une première image virtuelle pour le test

Maintenant que nous savons que notre playbook est fonctionnel nous allons l'intégrer dans la chaine de création de notre image.
Nous passerons donc par l'outil packer de hashicorp une des références dans les infrastructures cloud moderne.

L'objectif est d'utiliser les installations précédentes sur une distribution linux générique pour la rendre prête à l'emploi.

Voici comment le flux de création d'une VM avec packer s'organise :
1. Validation et parsing d'une **configuration** [HCL](https://github.com/hashicorp/hcl)
1. Lancement d'un plugin **builder** en fonction de notre infrastructure. Par exemple on peut build des images docker, virtualbox mais aussi des images dédiés à des cloud comme Azure que nous avons choisi
1. Le plugin créer, initialise les composants système majeurs de la machine puis démarre automatiquement la machine
1. Une fois la machine prête un système de **communicator** est disponible et nous pouvons lancer des commandes sur celle-ci. Nous utiliserons evidemment SSH.
1. Des **provisionners** sont ensuite joués pour configurer la machine. Nous utiliserons à cette étape le plugin ansible qui va nous permettre d'utiliser le travail précédent.
1. Enfin des **post processors** vont effectuer des traitements après le build une fois l'iso rendu. Par exemple nous pourrons upload **l'artifact** sur un registre comme [HCP](https://cloud.hashicorp.com/products/packer) ou sur un service comme [Azure resource manager](https://learn.microsoft.com/fr-fr/azure/azure-resource-manager/management/overview)

## 3. Créer votre définition de machine virtuelle avec packer

0. Sources

- https://www.packer.io/guides/packer-on-cicd/pipelineing-builds
- https://www.packer.io/docs

1. Initialisation des configurations de test

- [packer](https://www.packer.io/) - 1.7+ 

> INFO: recommandation : extension `4ops.packer`

Pour l'installer [cliquez ici](https://www.packer.io/downloads)


Vérification packer 1.8+ bien installé
```sh
packer --version
```

### Initialisez un projet packer

```sh
cd packer
touch sources.pk.hcl
touch ubuntu.pkr.hcl
```

> [packer/sources.pkr.hcl](packer/sources.pkr.hcl)

```packer
// In your sources file, you can create a configuration for a builder that you
// want to reuse between multiple steps in the build. Just leave the source
// and destination images out of this source, and set them specifically in each
// step without having to set all of the other options over and over again.

source "docker" "example" {
  commit = true
  // any other configuration you want for your Docker containers
}
```


> [ubuntu.pkr.hcl](ubuntu.pkr.hcl)

```packer
build {
  // Make sure to name your builds so that you can selectively run them one at
  // a time.
  name = "virtualbox-ovf"

  source "source.docker.example" {
    image = "ubuntu"
  }

  provisioner "shell" {
    inline = ["echo example provisioner"]
  }
  provisioner "shell" {
    inline = ["echo another example provisioner"]
  }
  provisioner "shell" {
    inline = ["echo a third example provisioner"]
  }

  // Make sure that the output from your build can be used in the next build.
  // In this example, we're tagging the Docker image so that the step-2
  // builder can find it without us having to track it down in a manifest.
  post-processor "docker-tag" {
    repository = "ubuntu"
    tag = ["step-1-output"]
  }
}

```

```bash
packer init
```

### Sources

- [authentication](https://www.packer.io/plugins/builders/azure#authentication-for-azure)
- [Arm](https://www.packer.io/plugins/builders/azure/arm)