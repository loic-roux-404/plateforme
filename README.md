# Paas Tutorial

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

```bash
conda create -n playbook-paas python=3.10
conda activate playbook-paas
pip install pip install molecule molecule-docker==2.0.0
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
mkdir playbook
cd playbook

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
roles: []
collections:
    - name: community.general
    - name: community.docker
    - name: kubernetes.core
```

Les **collections** vont servir à ajouter des fonctionnalités à ansible et ses directives de tâches. Ici on ajoute des fonctionnalités pour manipuler facilement les commandes docker et kubernetes.

Les **roles** correspondent à des suites de tâches qui vont installer et configurer un outil sur une machine. Ici on utilisera un [role kubernetes](https://github.com/geerlingguy/ansible-role-kubernetes) qui inclus comme dépendance ce role [docker](https://github.com/geerlingguy/ansible-role-docker).

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
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: instance
    # pour les utilisateurs de Mac M1 ou autre ARM
    # build:
    #   platform: "linux/arm64"
    image: jrei/systemd-ubuntu:22.04
    pre_build_image: true
    privileged: true
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:ro

provisioner:
  name: ansible
verifier:
  name: ansible

```

Le playbook de test va ensuite nous permettre de vérifier la bonne execution du rôle et de ses dépendances.

> [playbook/roles/kubeapps/molecule/default/converge.yml](playbook/roles/kubeapps/molecule/default/converge.yml)
```yaml

- name: Converge
  hosts: all
  vars:
    docker_install_compose_plugin: False
  pre_tasks:
    - name: Update apt cache.
      apt: update_cache=true cache_valid_time=600
      when: ansible_os_family == 'Debian'

    - name: Ensure test dependencies are installed (Debian).
      package: 
        name: ['iproute2', 'gpg-agent']
        state: present
      when: ansible_os_family == 'Debian'

    - name: Gather facts.
      action: setup

  roles:
    - role: geerlingguy.docker
    - role: geerlingguy.kubernetes
    - role: ../
```

Lancer le premier test avec `molecule test`. Vous pouvez aussi lancer `molecule test --destroy never` pour ensuite garder le container et debugger l'état du système après le provision ansible avec `docker exec -it "hash-container" sh`

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

## 3. Créer votre définition de machine virtuelle avec packer

1. Initialisation des configurations de test

- [packer](https://www.packer.io/) - 1.7+ 

Pour l'installer [cliquez ici](https://www.packer.io/downloads)

Initialisez un projet packer

```bash
packer init
```
