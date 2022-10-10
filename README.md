# Paas Tutorial

L'objectif de ce tutoriel est de vous permettre de créer sur une petite machine ou sur un serveur personnel un PaaS (Platform as a service) vous permettant de déployer des applications en microservices. Celui-ci sera basé sur [kubernetes]() pour la conteneurisation et [Openshift]() pour l'interface et les automatisation autour.

L'optique de cet outillage suivra :
- le principle **d'immutable infrastructure** avec l'idée de recréer plutôt que de mettre à jour. Ainsi nous aurons recour à des iso linux déjà prêt pour déployer la plateforme **kubernetes** / **openshift** directement sur un serveur.

- Le principe **d'infrastructure as code** en gardant toutes la spécification de notre infrastructure dans des configurations et scripts.

Pour cela nous ferons appel à 
- l'outil [`k3s`](https://k3s.io/) qui simplifie l'installation de kubernetes sur des machines ARM tout en restant compatible avec les architectures classiques X64. Il fourni par défaut des pods (containers en execution) pour inclure des fonctionnalités souvent recherchés sur ce type de configuration edge computing. (reverse proxy, configuration DNS...)
- ¨Packer pour créer des images iso de machine linux
- Ansible pour provisioner cette image
- Azure pour nous founir des serveurs accessible en ssh sur lequels nous pourrons mettre en ligne

## 0/ Installer les pré-requis

> Ce tutoriel est dédié à Linux et Mac
> Pour utilisateurs de windows il faut un [**WSL**](https://learn.microsoft.com/fr-fr/windows/wsl/install)

- **Multipass** [multipass](https://multipass.run/docs/how-to-guides#heading--install-multipass-)

Lancer une machine virtuelle ubuntu 22 avec

```
multipass launch --name primary --disk 4G
```

> INFO Nous n'allons pas utiliser Docker desktop pour nos tests car il a été déprécié comme runtime disponible dans les dernières versions de kubernetes.

- **Conda** : [docs.conda.io](https://docs.conda.io/en/latest/miniconda.html)

Installer le avec cette suite de commande, le setup est interactif et va vous demander de confirmer des localisations d'installation avec entrée et `y`. Accepter aussi de lancer le `conda init`.

```bash
wget https://repo.anaconda.com/miniconda/Miniconda3-py39_4.12.0-Linux-aarch64.sh -P /tmp
chmod +x /tmp/Miniconda3-py39_4.12.0-Linux-aarch64.sh
/tmp/Miniconda3-py39_4.12.0-Linux-aarch64.sh -p $HOME/miniconda
```

**Relancer votre shell** (`bash`)

- **Docker for linux :** 

```bash
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
chmod +x /tmp/get-docker.sh
sh /tmp/get-docker.sh

# Pouvoir utiliser un autre utilisateur que l'admin
sudo apt-get install -y uidmap
dockerd-rootless-setuptool.sh install

echo 'export DOCKER_HOST=unix:///run/user/1000/docker.sock' >> ~/.bashrc
```

##### Recommandations:
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


Créer votre espace de travail

> INFO Par défaut dans votre dossier utilisateur ubuntu vous pouvez utiliser les répertoires de votre système hôte dans votre machine virtuelle (mount) avec le dossier `~/Home`.

```bash 
mkdir paas-turorial/
```

Logger vous sur la machine ubuntu

```bash
multipass shell
```

> DANGER suivez bien la suite du tutoriel dans la machine ubuntu.

Ensuite pour créer l'environnement python avec ses dépendances

```bash
conda create -n playbook-paas python=3.9
conda activate playbook-paas
pip install ansible>=2.10.7 molecule[docker]
```

Pourquoi pas geler les versions des dépendances dans un fichier requirements pour qu'un autre environnement puisse facilement retrouver l'état de votre installation.

```sh
# ~/Home est un dossier de votre hôte (windows / mac)
cd ~/Home/paas-turorial/
echo "ansible==6.4.0\nmolecule==4.0.1\n" > requirements.txt
```

Le prochaine fois lorsque vous aurez recréer un nouvel environnement vous aurez juste à faire `pip install -r requirements.txt`

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

> INFO pour l'instant il y a un bug avec galaxy nous empêchant de récupérer la bonne version de k3s. On peut forcer l'utilisation direct de git pour récupérer la version 3.3.0

> [playbook/requirements.yaml](playbook/requirements.yaml)
```yaml
---
roles: 
    - name: xanmanning.k3s
      src: https://github.com/PyratLabs/ansible-role-k3s.git
      version: v3.3.0

collections:
    - name: community.general
    - name: community.docker
      version: 3.0.2
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
    - src: xanmanning.k3s
      version: v3.3.0
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
  - name: k3s-node-0
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

> WARNING : le `name` de la platform va nous servir d'addresse de l'hôte à laquelle ansible va pourvoir accèder en ssh dans notre environnement de test. Il est indispensable de le renseigner car le role k3s en a besoin pour bien créer les noeud du cluster kubernetes.

Le playbook de test va ensuite nous permettre de vérifier la bonne execution du rôle et de ses dépendances.

> [playbook/roles/kubeapps/molecule/default/converge.yml](playbook/roles/kubeapps/molecule/default/converge.yml)
```yaml
---
- name: Converge
  hosts: all
  become: true
  vars:
    molecule_is_test: true
    k3s_state: started
  roles:
    - role: "{{ lookup('env', 'MOLECULE_PROJECT_DIRECTORY') | basename }}"

  pre_tasks:

    - name: Ensure test dependencies are installed (Debian).
      package: 
        name: iptables
        state: present
        update_cache: true
      when: ansible_os_family == 'Debian'

    - name: Gather facts.
      action: setup

```

Ensuite nous allons vérifier que k3s est bien prêt avec deux vérifications :
- Vérification de la bonne initialisation du noeud **master**

> [playbook/roles/kubeapps/molecule/default/verify.yml](playbook/roles/kubeapps/molecule/default/verify.yml)
```yaml
---
- name: Verify
  hosts: all
  gather_facts: false
  tasks:
    - name: Get single node
      command: kubectl get nodes
      changed_when: false
      register: kubernetes_nodes

    - name: Assert master node ready
      when: '"Ready    master" in kubernetes_nodes.stdout'
      ansible.builtin.assert:
        that: true

    - name: Print list of running nodes.
      debug: var=kubernetes_nodes.stdout

```

Et ensuite dans la suite du fichier on fait une vérification des pods de la suite k3s.

Voici comment on procède.

Le retour de l'utilisation du `command` est stocké sous forme de variable ou fact grâce à `register: <nom variable>`. Ensuite on pourra faire nos tests sur le retour de la commande.

Notez bien l'utilisation des `filters ansible` hérité du langage de templating python `jinja` que l'on peut utiliser en ouvrant la moustache de ansible `"{{}}"`. Nous avons recour à :
- `select('nom action', 'valeur à comparé')` qui nous permet de faire une selection des cases de la liste répondant à certaines conditions (cf fonction `filter()` en javascript / java...)
- `reject`qui fait l'inverse d'un select en excluant les données d'une liste répondants à une condition
- `length` qui permet d'avoir la taille d'une liste

On accède également dans les `"{{}}"` aux fonctionnalités de python avec les méthodes rattachées aux type de données. Par exemple avec l'utilisation de `.split()` pour obtenir la liste des pods kubernetes dans une liste python.

Enfin `assert` permet de déclencher une erreur ansible si certaines conditions ne sont pas remplies.

```yaml
    - name: Get all running pods.
      command: kubectl get pods --all-namespaces
      changed_when: false
      register: kubernetes_pods

    - name: Tranform pods stdout to list
      ansible.builtin.set_fact:
        pods: "{{ kubernetes_pods.stdout.split('\n') | list | 
          reject('search', 'NAMESPACE') }}"

    - name: Print list of pods.
      debug: var=pods

    - name: Get running pods
      ansible.builtin.set_fact:
        running: "{{ pods | select('search', 'Running') }}"
    
    - name: Assert required pods up
      ansible.builtin.assert:
        that:
          - "{{ (pods | length) == 6 }}"
          - "{{ (running | select('search', '1/1') | length) == 4 }}"
          - "{{ (running | select('search', '2/2') | length) == 1 }}"
          - "{{ (pods | select('search', 'Completed')) == 1 }}"

```

Lancer le test avec `molecule test` et voilà vous avez un playbook prêt à l'emploi en suivant rigoureusement le concept du test driven development pour plus de fiabilité.

Vous pouvez aussi lancer `molecule test --destroy never` pour ensuite garder le container et debugger l'état du système après le provision ansible avec `docker exec -it "hash-container obtenu via docker ps" sh`

> Tips : En cas d'erreur `export ANSIBLE_STDOUT_CALLBACK=yaml` avant de lancer `molecule test` pour avoir un meilleur rendu de la possible erreur.

### E. Utiliser le rôle dans un playbook 

Nous allons créer le fichier `site.yaml` (dans le dossier `playbook/`) qui va se charger avec la commande `ansible-playbook` de lancer les rôles dans le bon ordre sur les machines.

Cette étape servira pour utiliser le playbook dans la [partie 2](#2-créer-une-première-image-virtuelle-pour-le-test) avec packer

> [playbook/site.yaml](playbook/site.yaml)
```yaml
---
- hosts: k3s-node-0
  gather_facts: True
  become: True
  become_user: root
  roles:
    - role: roles/kubeapps

```

Ensuite on définit la configuration des hôtes disponible pour notre playbook. On se contente ici de simplement se connecter en root sur localhost car nous allons provisionner sur un envionnement virtualisé en local plus tard.

> [playbook/inventories/k8s-paas/hosts](playbook/inventories/k8s-paas/hosts)

```ini
[k3s-node-0]
ansible_user=root
ansible_host=localhost

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

### A. Sources

- [packer docs](https://www.packer.io/docs)
- [packer on ci](https://www.packer.io/guides/packer-on-cicd/pipelineing-builds)
- [authentication](https://www.packer.io/plugins/builders/azure#authentication-for-azure)
- [Arm](https://www.packer.io/plugins/builders/azure/arm)

### Installation

Pour installer packer [c'est ici](https://www.packer.io/downloads)

> INFO: recommandation : extension `4ops.packer`

Vérification packer 1.8+ bien installé dans votre ligne de commande
```sh
packer --version
```

### B. Initialisez un projet packer et

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


> [packer/ubuntu.pkr.hcl](packer/ubuntu.pkr.hcl)

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

Toujours dans `packer/`

```bash
packer init
```
