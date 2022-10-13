# Paas Tutorial

L'objectif de ce tutoriel est de vous permettre de créer sur une petite machine ou sur un serveur personnel un PaaS (Platform as a service) vous permettant de déployer des applications en microservices. Celui-ci sera basé sur [kubernetes]() pour la conteneurisation et [Kubeapps]() pour l'interface et les automatisation autour.

L'optique de cet outillage suivra :
- le principle **d'immutable infrastructure** avec l'idée de recréer plutôt que de mettre à jour. Ainsi nous aurons recour à des iso linux déjà prêt pour déployer la plateforme **kubernetes** / **kubeapps** directement sur un serveur.

- Le principe **d'infrastructure as code** en gardant toutes la spécification de notre infrastructure dans des configurations et scripts.

Pour cela nous ferons appel à 
- l'outil [`k3s`](https://k3s.io/) qui simplifie l'installation de kubernetes sur des machines ARM tout en restant compatible avec les architectures classiques X64. Il fourni par défaut des pods (containers en execution) pour inclure des fonctionnalités souvent recherchés sur ce type de configuration edge computing. (reverse proxy, configuration DNS...)
- ¨Packer pour créer des images iso de machine linux
- Ansible pour provisioner cette image
- Azure pour nous founir des serveurs accessible en ssh sur lequels nous pourrons mettre en ligne

## 0/ Installer les pré-requis

Pour utilisateurs de **windows** il faut un [**WSL**](https://learn.microsoft.com/fr-fr/windows/wsl/install). Télécharger après avoir suivi cette documentation une distribution linux Ubuntu depuis le windows store.

[**Rancher**](https://rancherdesktop.io/) l'alternative mieux configurée et sans soucis de license à docker desktop. Il est portable sur windows et mac et permet d'avoir une expérience similaire à une utilisation native de docker sur linux.

Dans les choix proposés dans la mise en place :
- **Décocher kubernetes**
- Choisissez **dockerd** comme moteur de conteneurisation

Laissez le ensuite finir de s'initialiser.


### Maintenant tout ce que nous allons faire se trouve dans la ligne de commande.

**Conda** : [docs.conda.io](https://docs.conda.io/en/latest/miniconda.html). Installer simplement avec le setup `.pkg` pour mac.

> Pour Linux et Windows avec WSL utilisez la ligne de commande ci dessous pour l'installer

```bash
wget https://repo.anaconda.com/miniconda/Miniconda3-py39_4.12.0-Linux-aarch64.sh -P /tmp
chmod +x /tmp/Miniconda3-py39_4.12.0-Linux-aarch64.sh
/tmp/Miniconda3-py39_4.12.0-Linux-aarch64.sh -p $HOME/miniconda
```

**Relancer votre shell pour utiliser** (`bash`)

##### Recommandations:

Extensions vscode : 

  - `redhat.ansible` serveur de langage ansibke
  - `ms-kubernetes-tools.vscode-kubernetes-tools` debug des cluster directement depuis l'IDE
  - `mindaro.mindaro` permet de faire pont vers kubernetes

> **Warning** Les shell un peu exotique comme fish pour l'utilisation de molecule ne sont pas recommandés

# I/ Créer la machine virtuelle servant de cluster

## Un iso pour Azure

## 1. Le playbook ansible

L'objectif d'ansible de est de déployer des configurations et des outils sur des machines. A l'aide d'un format de configuration simple
proche de l'algorithmie nous pourrons amener tous les outils indispensable à la création de notre PaaS.

### A. Installer ansible

Ansible est un outil dépendant de l'écosystème python. Pour simplifier la gestion des dépendances 
qui risquent de faire conflit avec d'autres installations
de python, nous allons utiliser `miniconda`.

Molecule est un outil permettant de tester nos suite de configurations ansible contenus dans des rôles ou des tâches.

On initialise un environnement virtuel python avec sa propre version de **python 3.10** et les dépendences ansible et molecule. Ainsi nos dépendences n'entrent pas en conflit avec d'autres non compatibles installés pour un autre projet.

Créer votre espace de travail :

```bash 
mkdir paas-turorial/
```

Ensuite pour créer l'environnement python avec ses dépendances

```bash
conda create -n playbook-paas python=3.9
conda activate playbook-paas
pip install ansible molecule[docker]
```

Pourquoi pas geler les versions des dépendances dans un fichier requirements pour qu'un autre environnement puisse facilement retrouver l'état de votre installation.

```sh
# ~/Home est un dossier de votre hôte (windows / mac)
cd paas-turorial/
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

### B. Playbook ansible

n playbook ansible est un projet chargé de lancer plusieurs rôles différents sur des machines disponibles sur le réseau via **ssh**. (localhost par exemple peut être provisioné)

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

### C. Initialiser le rôle

Pour suivre la convention d'ansible nous allons procédé en créant un role interne à notre projet. L'objectif sera d'installer [kubeapps](https://github.com/vmware-tanzu/kubeapps) l'outil qui nous permettra de déployer les containers de nos applications et leurs dépendances.

Dans le dossier `playbook` faites donc :

```bash
mkdir roles
cd roles
ansible-galaxy init kubeapps
cd kubeapps
# Créer un scénario de test par défaut
molecule init scenario -d podman default
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

### D. Cluster kubernetes et premiers tests sur notre rôle 

Nous allons d'abord définir l'utilisaton d'une distribution ubuntu pour installer nos outils. Pour les tests en local nous faisons donc du docker in docker ce qui impose quelques difficulés de test parfois et des configurations particulières.

> [playbook/roles/kubeapps/molecule/default/molecule.yml](playbook/roles/kubeapps/molecule/default/molecule.yml)
```yaml
---
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: node-0
    image: geerlingguy/docker-${MOLECULE_DISTRO:-ubuntu2004}-ansible:latest
    command: ${MOLECULE_DOCKER_COMMAND:-""}
    privileged: true
    pre_build_image: true
    published_ports:
      - 6443
      - 80
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
      - /var/lib/rancher/k3s
    networks:
      - name: k3snet
    tmpfs:
      - /var/run
      - /run

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
---
- name: Converge
  hosts: all
  become: true
  vars:
    molecule_is_test: true

  roles:
    - role: "{{ lookup('env', 'MOLECULE_PROJECT_DIRECTORY') | basename }"

  pre_tasks:
    - name: Ensure test dependencies are installed (Debian).
      package: 
        name: iptables
        state: present
        update_cache: true
      when: ansible_os_family == 'Debian'

```

On lance le cluster avec une autre configuration du role pour démarrer le cluster k3s.

> [playbook/roles/kubeapps/molecule/default/playbook.yml](playbook/roles/kubeapps/molecule/default/playbook.yml)
```yaml
---
- name: Converge
  hosts: all
  become: true
  vars:
    molecule_is_test: true
  roles:
    - role: "{{ lookup('env', 'MOLECULE_PROJECT_DIRECTORY') | basename }"

```

Ensuite nous allons vérifier que k3s est bien prêt avec deux vérifications :
- Vérification de la bonne initialisation du noeud **master** simplement en vérifiant que le retour de la commande contient bien "Ready    master".

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

    - name: Print list of running nodes.
      debug: var=kubernetes_nodes.stdout

    - name: Assert master node ready
      ansible.builtin.assert:
        that: '"Ready    control-plane,master" in kubernetes_nodes.stdout'

    - name: Ensure k3s service is restarted
      ansible.builtin.systemd:
        name: k3s
        state: restarted

```

Et ensuite dans la suite du fichier on fait une vérification des pods de la suite k3s.

Voici comment on procède.

Le retour de l'utilisation du `command` est stocké sous forme de variable ou fact grâce à `register: <nom variable>`. Ensuite on pourra faire nos tests sur le retour de la commande.

Notez bien l'utilisation des `filters ansible` hérité du langage de templating python `jinja` que l'on peut utiliser en ouvrant la moustache de ansible `"{{}}"`. Nous avons recour à :
- `select('nom action', 'valeur à comparé')` qui nous permet de faire une selection des cases de la liste répondant à certaines conditions (cf fonction `filter()` en javascript / java...)
- `reject`qui fait l'inverse d'un select en excluant les données d'une liste répondants à une condition
- `length` qui permet d'avoir la taille d'une liste

On accède également dans les `"{{}}"` aux fonctionnalités de python avec les méthodes rattachées aux type de données. Par exemple avec l'utilisation de `.split()` pour obtenir la liste des pods kubernetes dans une liste python.

Enfin `assert` permet de déclencher une erreur ansible si certaines conditions ne sont pas remplies. Ces conditions sont multiples et placées dans la liste `pod_assertions`.

```yaml
    - name: Wait for pods to start fully
      ansible.builtin.pause:
        minutes: 1

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
        running: "{{ pods | select('search', 'Running') | list }}"

    - name: Set assertions list
      ansible.builtin.set_fact:
        pod_assertions:
          - "{{ (pods | length) == 7 }}"
          - "{{ (running | select('search', '1/1') | list) | length >= 3 }}"
          - "{{ (running | select('search', '2/2') | list) | length == 1 }}"
          - "{{ (pods | select('search', 'Completed') | list) | length == 2 }}"

    - name: Assert required pods up
      ansible.builtin.assert:
        that: "{{ pod_assertions | list }}"
        fail_msg: "{{ pod_assertions | join(' - ') }}"


```

Lancer le test avec `molecule test` et voilà vous avez un playbook offrant un cluster kubernetes prêt à l'emploi tout en suivant rigoureusement le concept du test driven development pour plus de fiabilité.

> INFO : Vous pouvez aussi lancer `molecule test --destroy never` pour ensuite garder le container et debugger l'état du système après le provision ansible avec `docker exec -it node-0 bash`

> INFO : En cas d'erreur `export ANSIBLE_STDOUT_CALLBACK=yaml` avant de lancer `molecule test` pour avoir un meilleur rendu de la possible erreur.

> **Bonus : Vscode avec kubernetes**

Nous allons chercher la kubeconfig dans notre container qui embarque K3s et le cluster.
Récupérez l'identifiant du container avec :

```sh
docker ps | grep node-0 | awk '{print $1}'
# ex de retour 61a74719f7c4
```

Copier la kube config k3s avec :

```sh
docker cp 61a74719f7c4:/etc/rancher/k3s/k3s.yaml ~/.kube/config
```

Si vous n'avez pas kubectl en local :
- [Pour mac](https://kubernetes.io/docs/tasks/tools/install-kubectl-macos/)
- [Pour Wsl / Linux](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)

On check ensuite avec `kubectl cluster-info` qui devrait nous donner les information du node k3s.

##### Ensuite sur `vscode` utiliser ces paramètres utilisateur pour voir et utiliser votre cluster

> [.vscode/settings.json](.vscode/settings.json)
```json
    "vs-kubernetes": {
        "vs-kubernetes.knownKubeconfigs": [
            "<Chemin-vers-home>/.kube/config"
        ],
        "vs-kubernetes.kubeconfig": "<Chemin-vers-home>/.kube/config"
    }
```

Et voilà vous avez accès à une interface pour controller votre cluster directement depuis vscode. Utiliser cette configuration `json` autant que vous voulez dans les repository de vos applications pour avoir une expérience au plus proche de la production.

### E. Tâches ansible pour l'environnement kubernetes en local

La tâche **Mkcert** va nous permettre d'activer en local le https en TLS. Cela va nous permettre d'avoir une expérience encore plus proche de la réalité de la production.

Pour l'installer :

- **Linux** :

> Renseigner bien `arm64` à la place de `amd64` si vous possèder ce genre de processeur

```sh
wget https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-linux-amd64
sudo mv mkcert-v1.4.4-linux-amd64 /usr/local/bin/mkcert && chmod +x /usr/local/bin/mkcert
```

- **Mac** : `brew install mkcert`

Ensuite générons les certificats pour activer https sur tous les domaines finissant par `k3s.localhost`

```
mkdir certs/
echo 'certs/*
!.gitkeep' >> .gitignore # we don't want to commit auto-signed certs
mkcert -install
mkcert -cert-file certs/local-cert.pem -key-file certs/local-key.pem "k3s.localhost" "*.k3s.localhost" 
```

https://blog.stephane-robert.info/post/homelab-ingress-k3s-certificats-self-signed/

### F. Développement de notre rôle pour installer la solution de PaaS Kubeapps

Donc dans [playbook/roles/kubeapps/tasks]([playbook/roles/kubeapps/tasks) nous allons créer les fichiers suivants :

- `dev.yaml` : ce fichier servira à tester en local notre PaaS
- `install.yaml`: celui-ci installe le binaire de la solution et déploie sur notre cluster kubernetes (k3s)


### G. Playbook et inventaire final

Nous allons créer le fichier `site.yaml` (dans le dossier `playbook/`) qui va se charger avec la commande `ansible-playbook` de lancer les rôles dans le bon ordre sur les machines.

Cette étape servira pour utiliser le playbook dans la [partie 2](#2-créer-une-première-image-virtuelle-pour-le-test) avec packer

> [playbook/site.yaml](playbook/site.yaml)
```yaml
---
- hosts: node-0
  gather_facts: True
  become: True
  become_user: root
  roles:
    - role: roles/kubeapps

```

Ensuite on définit la configuration des hôtes disponible pour notre playbook. On se contente ici de simplement se connecter en root sur localhost car nous allons provisionner sur un envionnement virtualisé en local plus tard.

> [playbook/inventories/k8s-paas/hosts](playbook/inventories/k8s-paas/hosts)

```ini
[node-0]
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
