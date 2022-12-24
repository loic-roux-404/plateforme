# Paas Tutorial

## Requis

- Un PC / Mac peut importe l'OS
- Des bases d'administration linux
- Un minimum de culture sur les systèmes d'Information
- Connaissance des concepts d'environnements isolés linux ou **containers**
- Un compte [github](http://github.com/)
- Un compte [azure](https://azure.microsoft.com/fr-fr/) avec le crédit de 100$ offert pour les étudiants (avec l'email myges cela fonctionne normalement)
- Valider votre compte github student pour ne pas avoir à acheter de nom de domaine [https://education.github.com/globalcampus/student](https://education.github.com/globalcampus/student), valider le compte avec votre adresse mail de l'université.

## Intro

L'objectif de ce tutoriel est de vous permettre de créer sur une petite machine ou sur un serveur personnel un PaaS (Platform as a service) vous permettant de déployer des applications en microservices. Celui-ci sera basé sur [kubernetes](https://kubernetes.io/fr/) pour la conteneurisation et [Kubeapps](https://kubeapps.dev/) pour l'interface de déploiement. En bonus si le temps nous le permet on utilisera concourse pour ajouter l'automatisation des mise à jour de l'application.

L'optique de cet outillage suivra :
- le principle **d'immutable infrastructure** avec l'idée de recréer plutôt que de mettre à jour. Ainsi nous aurons recour à des iso linux déjà prêt pour déployer la plateforme **kubernetes** / **kubeapps** directement sur un serveur.

- Le principe **d'infrastructure as code** en gardant toutes la spécification de notre infrastructure dans des configurations et scripts.

Pour cela nous ferons appel à un socle technique composé de :
- l'outil [`k3s`](https://k3s.io/) qui simplifie l'installation de kubernetes sur des machines ARM tout en restant compatible avec les architectures classiques X64. Il fourni par défaut des pods (containers en execution) pour inclure des fonctionnalités souvent recherchés sur ce type de configuration edge computing. (reverse proxy, configuration DNS...)
- [¨Packer](https://www.packer.io/) pour créer des images iso de machine linux
- [Ansible](https://www.ansible.com/) pour provisioner cette image
- [Azure](https://azure.microsoft.com/fr-fr/) pour nous founir des serveurs accessible en ssh sur lequels nous pourrons mettre en ligne

## 0/ Installer les pré-requis

Pour utilisateurs de **windows** il faut un [**WSL**](https://learn.microsoft.com/fr-fr/windows/wsl/install). 

- Télécharger après avoir suivi cette documentation la distribution linux ``Ubuntu 20.04.5 LTS`` depuis le windows store. 
- **+ Windows terminal bien que pas obligatoire il est très pratique pour accèder au shell**

Ensuite dans vscode installer l'extension wsl `ms-vscode-remote.remote-wsl`.

[**Rancher**](https://rancherdesktop.io/) l'alternative mieux configurée et sans soucis de license à docker desktop. Il est portable sur windows et mac et nous permet d'avoir une expérience docker complète et fonctionnelle sur notre machine.

Dans les choix proposés dans la mise en place :
- **Décocher kubernetes**
- Choisissez **dockerd** comme moteur de conteneurisation

Laissez le ensuite finir de s'initialiser.

# I/ Partie 1 : Provisionning du PaaS sous Linux

### Maintenant tout ce que nous allons faire se trouve dans la ligne de commande sur un shell `bash` ou `zsh` 

**Conda** : [docs.conda.io](https://docs.conda.io/en/latest/miniconda.html). Installer simplement avec le setup `.pkg` pour mac.

> Pour Linux et Windows avec WSL utilisez la ligne de commande ci dessous pour l'installer
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

Veillez à bien accepter toutes les propositions (licence terms, initialize Miniconda3)

**Relancer votre shell pour utiliser conda** (commande `exec $SHELL`)

#### Extensions vscode recommandés : 

  - `redhat.ansible` serveur de langage ansibke
  - `ms-kubernetes-tools.vscode-kubernetes-tools` debug des cluster directement depuis l'IDE
  - `mindaro.mindaro` permet de faire pont vers kubernetes

## 1. Le playbook ansible

L'objectif d'ansible de est de déployer des configurations et des outils sur des machines. A l'aide d'un format de configuration simple
proche de l'algorithmie nous pourrons amener tous les outils indispensable à la création de notre PaaS.

### A. Installer ansible

Ansible est un outil dépendant de l'écosystème python. Pour simplifier la gestion des dépendances 
qui risquent de faire conflit avec d'autres installations
de python, nous allons utiliser `miniconda`.

Molecule est un outil permettant de tester nos suite de configurations ansible contenus dans des rôles ou des tâches.

Pour commencer bonne habitude, on met à jour linux :

```bash
apt update && apt upgrade -y
```

Puis redemarrer l'app Ubuntu. Si des problèmes appraissent encore lancer la comande `wsl --shutdown` depuis un powershell en administrateur avant de lancer le shell WSL.

Ensuite on initialise un environnement virtuel python avec sa propre version de **python 3.10** et les dépendences ansible et molecule. Ainsi nos dépendences n'entrent pas en conflit avec d'autres pouvant être incompatible.

Créer votre espace de travail :

```bash
cd ~
mkdir paas-tutorial/
```

Ensuite pour créer l'environnement python avec ses dépendances

```bash
conda create -n playbook-paas python=3.9
conda activate playbook-paas
```

<!--

Installer la bonne version de pip :
```bash
sudo apt install python3-pip
pip install --upgrade pip
echo "export PATH=\"${HOME}/.local/bin:$PATH\"" >>"${HOME}"/.bashrc
```
-->


Installer ansible et molecule préconfiguré pour utiliser docker (rancher desktop).
```bash
pip install ansible molecule[docker]
```

> **Warning** Les shell un peu exotique comme fish pour l'utilisation de molecule ne sont pas recommandés

Vérifier que tous fonctionne avec `ansible --version`.

Vous devriez avoir `ansible [core 2.13.4]` dans le retour

### **Bonus** pour faire fonctionner l'extension VsCode ansible

> **Warning**: Utilisateur du WSL **Pour utiliser vscode, faites le impérativement via la ligne de commande linux WSL dans votre projet `~/paas-tutorial`** : `code .`

> Vscode : .vscode/settings.json
> Remplacez bien le chemin avec le résultat de cette commande `which python`
> miniconda sur wsl, mambaforge sur mac
```json
{
    "ansible.python.interpreterPath": "<User-Path>/mambaforge/envs/playbook-paas/bin/python"
}
```

### B. Playbook ansible

Un playbook ansible est un projet chargé de lancer plusieurs rôles différents sur des machines disponibles sur le réseau via **ssh**. (localhost par exemple peut être provisioné).

Pour aller plus loin dans le fonctionnement de ansible, cet outil s'appuie intégralement sur l'environnement python installé sur une machine invités (que l'on provisionne). Grâce à python ansible va abstraire la complexité de l'administration système linux avec des **déclaration yaml**, des **templates** pour créer des fichiers dynamiquements, des **structure de contrôles** algorithmique et des variables manipulables avec des **filters**.

#### On Commence :

On va créer un dossier playbook pour mettre tout ce qui concerne ansible

Aussi, on va geler les versions des dépendances dans un fichier requirements pour qu'un autre environnement puisse facilement retrouver l'état de votre installation sans problèmes de compatibilités.

```sh
# ~/Home est un dossier de votre hôte (windows / mac)
mkdir -p paas-tutorial/playbook
cd paas-tutorial/playbook
echo "ansible==6.4.0\nmolecule==4.0.1\n" > requirements.txt
```

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

> **Note** pour l'instant il y a un bug avec galaxy nous empêchant de récupérer la bonne version de k3s. On peut forcer l'utilisation direct de git pour récupérer la version 3.3.0

> [playbook/requirements.yaml](playbook/requirements.yaml)
```yaml
---
---
roles: 
    - name: xanmanning.k3s
      src: https://github.com/PyratLabs/ansible-role-k3s.git
      version: v3.3.0

collections:
    - name: community.general
    - name: kubernetes.core
    - name: azure.azcollection
    
```

Les **collections** vont servir à ajouter des fonctionnalités à ansible et ses directives de tâches. Ici on ajoute les fonctionnalités fondamentales ainsi que celles pour manipuler notre cluster kubernetes (abstraction de la commande `kubectl`).

Les **roles** correspondent à des suites de tâches qui vont installer et configurer un outil sur une machine. Ici on utilisera un [role k3s](https://github.com/PyratLabs/ansible-role-k3s) qui s'occupe de configurer en fonction de nos paramètre le cluster k3s.

> **Note** K3s n'utilise pas `docker` mais `containerd` pour utiliser les fonctionnalités de container linux.

Pour installer ces requirements maintenant on lance dans le dossier `playbook/` :

```bash
ansible-galaxy install -r requirements.yaml
```

Normalement tous est installé correctement et prêt à l'emploi.

### C. Initialiser le rôle installant un Cluster kubernetes (k3s) 

Pour suivre la convention d'ansible nous allons procédé en créant un role interne à notre projet. L'objectif sera d'installer un ensemble de solution autour de kubeapps pour le faire fonctionner de manière sécurisée en local et en production.

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

Nous allons ensuite mettre à jour les métadonnées ansible galaxy avec notamment la dépendance kubernetes (rôle k3s)

> Ligne 50 de [playbook/roles/kubeapps/meta/main.yml](playbook/roles/kubeapps/meta/main.yml)
```yaml
dependencies:
    - src: xanmanning.k3s
      version: v3.3.0
```

Ensuite vous devez obligatoirement définir ces Informations sur les metas du rôles:

> [playbook/roles/role-kubeapps/meta/main.yml](playbook/roles/role-kubeapps/meta/main.yml)
```yaml
galaxy_info:
  author: loic-roux-404
  namespace: paas_tutorial
  description: kubeapps deployment
  role_name: kubeapps
```

Le rôle kubernetes se lancera donc directement avant les tâches de celui de kubeapps.

### D. Notions théorique sur kubernetes (k3s)

### Noeud

Un nœud est une machine de travail dans Kubernetes, un groupe de noeud va composer ce qu'on appelle un cluster (grappe) de serveurs. Chaque nœud contient les services nécessaires à l'exécution de pods et est géré par les composants du master.

> **Note** dans notre cas nous ferons appel à un seul noeud master

### Namespace

Clusters virtuels présents sur le même cluster physique. Ces clusters virtuels sont appelés namespaces. Ils utilisents les fonctionnalités de groupage de linux Cgroup.

### Les pods

[source documentation officielle](https://kubernetes.io/fr/docs/concepts)

Un pod est un groupe d'un ou plusieurs conteneurs (comme des conteneurs Docker), ayant du stockage/réseau partagé, et une spécification sur la manière d'exécuter ces conteneurs. Les éléments d'un pod sont toujours co-localisés et co-ordonnancés, et s'exécutent dans un contexte partagé. Un pod modélise un "hôte logique" spécifique à une application - il contient un ou plusieurs conteneurs applicatifs qui sont étroitement liés.

Un pod peut être :
- Temporaire (Completed) pour effectuer une tâches particulière (cron, jouer des script, déploiement d'autres pods...)
- Définitif soit une application en éxecution

### Déploiement

Comme un le fait en développement un fichier docker-compose, cette ressource décrits la mise en place des containers avant de les placer dans un pod (plusieurs containers peuvent se placer dans un pod)

### Services
Une manière abstraite d'exposer une application s'exécutant sur un ensemble de Pods en tant que service réseau.

## Ingress

Il s'agit du composant de kubernetes permettant de gérer au travers d'une technologie de reverse proxy et de répartition de charge le traffic réseau entrant (http(s)).

> **Note** Un **reverse proxy** est à l'inverse d'un proxy chargé d'effectuer une action à partir d'une requète réseau externe. On l'utilise majoritairement avec un serveur DNS qui fait pointé des noms de domaines et sous domaines vers l'adresse Ip du serveur sur lequel un reverse proxy est installé.
> Par exemple il va servir à rediriger le traffic de la requète `kubeapps.k3s.local` vers une addresse et port réseau attribué par kubernetes à un pod.

Voici pour résumer l'achitecture réseau d'un cluster kubernetes :

![architecture réseau kubernetes](./images/k8s-archi.jpg)

## Spécificité de k3s

K3s est une sorte d'implémentation allèger de kubernetes pour le rendre portable sur plus de plateformes comme des nano ordinateur et des infrastructures en périphérie de réseau (Edge computing).

Nous avons donc à la place de `etcd` comme outil de persistence du stockage `sqlite`, un ingress (ou reverse proxy) par défaut à `traefik` et on trouve nombreux composants coeur comme le kuber-controller-manager ou le scheduder ramené au plus proche du système (services réseaux au lieu de pods).

## L'architecture autour de Kubeapps

Pour rappel kubeapps nous sert à déployer des applications conteneurisée "packagées" au format helm chart dans un cluster kubernetes. Il à accès à
Il aura besoin de plusieurs autres outils pour fonctionner de manière sécurisée avec kubernetes.

- Une autorité de certification locale et Acme server pour nos tests [pebble](https://github.com/letsencrypt/pebble)
- Un gestionnaire de certificats dédié à kubernetes [cert-manager](https://cert-manager.io/)
- Un **serveur openid** exploitant une application oauth2 github : [dex idp](https://dexidp.io/)

Voilà donc tout ce qu'on aura à mettre en place dans notre rôle ansible.

### E. Premiers tests sur le rôle 

Nous allons d'abord définir l'utilisaton d'une distribution ubuntu pour installer nos outils. Pour les tests en local nous faisons du **docker in docker** ce qui impose des configurations particulières.

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
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
      - /var/lib/rancher/k3s
    network_mode: host
    tmpfs:
      - /var/run
      - /run

provisioner:
  name: ansible
verifier:
  name: ansible

```

> **Warning** : le `name` de la platform va nous servir d'addresse réseau par laquelle ansible sur l'hôte va pourvoir accèder en ssh. Il est indispensable de le renseigner car le role k3s en a besoin pour bien créer les noeud du cluster kubernetes. (même si on en utilise un seul)

L'image du container `geerlingguy/docker-${MOLECULE_DISTRO:-ubuntu2004}` va nous permettre d'utiliser un linux préconfiguré qui s'initialise avec le démon `systemd`. Celui ci est une fonctionnalité assez neuve du coeur et recommandée pour la gestion des services en arrière plan (daemons) soit ici k3s

On note que l'on publie le port `80` et `443` à des fins de debug pour exposer Ingress.

> `32444` le port pebble servira plus tard pour accèder à notre serveur ACME

> ****Warning** vérifiez bien que aucun autre processus su votre machine n'utilise déjà le port 80 et 443**

Les **volumes** que l'on utilise servent à rendre disponible des fonctionnalités du coeur linux désactivées par défaut sur des containers docker comme `systemd` et les [espaces de nom](https://fr.wikipedia.org/wiki/Espace_de_noms) / [`cgroup` version 2](https://kubernetes.io/docs/concepts/architecture/cgroups/). 
Même chose pour les répertoire temporaire `tmpfs` qui assurent le bon fonctionnement de ces outils. 
Enfin `priviledgied: true` nous donne les droits administrateur complets sur le système du container.

Le playbook `verifier` va ensuite nous permettre de tester la bonne execution du rôle et de ses dépendances.

Le playbook converge

> [playbook/roles/kubeapps/molecule/default/converge.yml](playbook/roles/kubeapps/molecule/default/converge.yml)
```yaml
---
- name: Converge
  hosts: all
  become: true
  vars:
    molecule_is_test: true

  roles:
    - role: "{{ lookup('env', 'MOLECULE_PROJECT_DIRECTORY') | basename }}"

  pre_tasks:
    - name: Ensure test dependencies are installed.
      package: 
        name:
          - iptables
          - curl
          - dnsutils
        state: present
        update_cache: true
      when: ansible_os_family == 'Debian'

    - name: Install pre-requisites for k8s module
      ansible.builtin.pip:
        name:
          - openshift
          - pyyaml
          - kubernetes

```

> Notes :
> - `hosts: all` permet de jouer le playbook sur tous les hôtes
> - `role: {{etc...}}` résoud le chemin de fichier vers le répertoire du rôle
> - Les pré-tâches servent à installer des packages linux et python manquant à notre container utiles pour l'environnement local et les tests.

Nous allons ensuite vérifier que k3s est bien prêt avec deux vérifications :

- Vérification de la bonne initialisation du noeud **master** 
simplement en vérifiant que le retour de la commande contient bien "Ready    master".

On utilise pour cette fois la commande `kubectl` directement. Pour en savoir plus pour cette commande centrale dans l'utilisation d'un cluster kubernetes [c'est ici](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands)

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
        that: '"node-0   Ready    control-plane,master" in kubernetes_nodes.stdout'

```

Lancer votre premier test avec `molecule test` et voilà vous avez un playbook offrant un cluster kubernetes prêt à l'emploi tout en suivant rigoureusement le concept du test driven development pour plus de fiabilité.

> **Note** : Vous pouvez aussi lancer `molecule test --destroy never` pour ensuite garder le container et debugger l'état du système après le provision ansible avec `molecule login` (qui équivaut à `docker exec -it node-0 bash`)

> **Note** : En cas d'erreur `export ANSIBLE_STDOUT_CALLBACK=yaml` avant de lancer `molecule test` pour avoir un meilleur rendu de la possible erreur.

Eensuite dans la suite du fichier on procède à une vérification des pods de la suite k3s. 

> Vous pourrez relancer seulement la suite de vérification avec `molecule verify` si votre container n'a pas été détruit (`--destroy false`)

Nous savons ici que k3s est lancé. En sachant que ce rôle est externe nous n'avons pas besoin de faire plus de tests sur ces composants centraux disposés dans le namespace `kube-system`.

On valide bien que le service est de type cluster ip. Cela signifie qu'il est exposé dans le cluster avec sa propre adresse. Si le type aurait été vide cela aurait voulu dire soit que quelque chose n'est pas correctement configuré soit que kubernetes n'est pas disposé à attribué une configuration réseau à ce service.

> **INFO** Kubernetes utilise l'outil natif de linux `iptables` pour faire fonctionner cette ressource.

### F. Vscode avec kubernetes

Pour consolider le debuggage de notre environnement de dev ops nous allons intégré notre cluster kubernetes dans l'IDE vscode.

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

On check ensuite avec `kubectl cluster-info` qui devrait nous donner les informations du node k3s.

##### Ensuite sur `vscode` utilisez ces paramètres utilisateur pour voir et utiliser le cluster

> Pour afficher le chemin vers home `cd ~ && pwd && cd -`

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

### G. Système d'installation des manifests des composants requis par kubeapps

Nous allons avoir recours ici à deux nouvelles notions de l'écosytème de kubernetes qui sont

- Les manifests que l'on utilise pour décrire une resources (pods, service, ingress,...) à déployer dans le cluster avec la commande `kubectl`

Pour l'exemple cette commande `kubectl get pods -n kube-system` récupère la liste des pods dans le namespace du système de k3s
Voici le retour qu'elle nous donne :

```
  "local-path-provisioner-84bb864455-8dz4g   1/1     Running     0          7h58m",
  "svclb-traefik-qv89r                       2/2     Running     0          7h57m",
  "coredns-574bcc6c46-pr6vq                  1/1     Running     0          7h58m",
  "metrics-server-ff9dbcb6c-ncr4n            1/1     Running     0          7h58m",
  "traefik-56c4b88c4b-p4xt6                  1/1     Running     0          7h57m",
```

Les commandes kubectl fonctionnent tout le temps de la sorte `kubectl <action> <resource> -n <namespace> -o <format>`

- `<action>` soit une action crud : `edit`, `get`, `describe`
- `<resource>` pour en savoir plus sur les différentes ressources disponibles `kubectl api-resources`. Nous aurons majoritairement recour à `deployment`, `service`, `ingress`, `pod`, `secret`, `configmap`
- `-o` est très pratique quand on veut un vrai détail sur les resources avec notamment le `-o yaml`

> La commande pod est un peu particulière : voivi un exemple utilisant le retour au dessus en exemple : `kubectl get pods -n kube-system traefik-56c4b88c4b-p4xt6` (on précise le nom complet du pod)

> Astuce le flag `-A` permet de regarder tous les pod sur n'importe quel namespace. Par exemple `kubectl get po -A` (`po` est un diminutif de `pods`, on a aussi par exemple `svc` pour service)

- [Helm](https://helm.sh/fr/docs/intro/using_helm/) un gestionnaire de paquet pour distribuer des **charts** (ou package) contenant des suites de manifest kubernetes à déployer sur le cluster.
Pour cela nous aurons recour à cette utilisation au travers de k3s et d'un [module](https://docs.k3s.io/helm#automatically-deploying-manifests-and-helm-charts) permettant le deploiement automatique de resources kubernetes.

Donc dans [playbook/roles/kubeapps/tasks]([playbook/roles/kubeapps/) nous allons travailler sur ces éléments de ansible :

- `tasks/main.yaml`: déclenche certaines suite de tâches en fonction de l'état choisi dans les variables de configuration. Elles sont définis dans l'ordre :

- Les variables par défaut `default/main.yaml`. On pourra par la suite les surcharger avec celle du playbook (inventories/{env}/all.yaml)

- `templates/` qui conttient des fichier `.j2` ou templates `jinja` représentant plusieurs manifests kubernetes.

- `tasks/manifests.yaml` : celui-ci va s'occuper de placer les manifests kubernetes dans le répertoire `/var/lib/rancher/k3s/server/manifests` pour que k3s déploie automatiquement les resources décrites dans ceux-ci.

> Source pour plus d'informations [doc k3s](https://docs.k3s.io/helm#customizing-packaged-components-with-helmchartconfig)

On rempli le fichier d'entrée comme ceci :

[playbook/roles/kubeapps/tasks/manifests.yml](playbook/roles/kubeapps/tasks/manifests.yml#L10)

```yaml
---
- import_tasks: manifests.yml
  tags: [kubeapps]
```

> Astuce: Voici la commande molecule qui permettra de lancer seulement les taches avec le `tags: [kubeapps]` ceci une fois notre playbook utilisable :

```bash
molecule test --destroy never -- -t kubeapps
```

Puis allons configurer une suite de tâches pour installer les manifests qu'ils soit une ressource api ou un chart helm.

On commence par mettre en place une boucle ansible prenant en paramètre une liste de dictionnaires python. Ceux-ci comportes comme sous propriété :
- `src` : un fichier manifest au format `yaml.j2` à déployer sur le noeud. Ce format donne la possibilité d'intégrer les `variables` et `facts` ansible. 
- `ns` : pour un namespace sur lequel ajouter le chart et pouvant aussi être un déploiement kubernets dont il va valloir attendre le succès.
- `deploy`: Pour préciser le nom du déploiement ci celui-ci n'est pas le même que le namespace 
- `condition`: Simple booléen pour executé ou non le manifest

> **Note** Les facts sont des variables définis dynamiquement à partir de l'environnement ou de ce qu'on décide de conserver de nos traitement pendant le processus ansible

[playbook/roles/kubeapps/tasks/manifests.yml](playbook/roles/kubeapps/tasks/manifests.yml)

```yml
---
- name: "Deploy {{ item.src }} to k3s crd processor"
  ansible.builtin.template:
    src: "{{ item.src }}.j2"
    dest: "/var/lib/rancher/k3s/server/manifests/{{ item.src }}"
    owner: "{{ kubeapps_user }}"
    group: "{{ kubeapps_user }}"
    mode: '0644'

- name: "Wait {{ item.src }} deployment complete"
  kubernetes.core.k8s_info:
    api_version: v1
    kind: Deployment
    name: "{{ item.deploy }}"
    kubeconfig: /etc/rancher/k3s/k3s.yaml
    wait: yes
    wait_sleep: 5
    wait_timeout: 600
    wait_condition:
      type: Progressing
      status: "True"
      reason: "NewReplicaSetAvailable"
    # Many times deployment name is the same that namespace
    namespace: "{{ item.ns | d(item.deploy) }}"
  when: item.deploy | default(false) or item.ns | default(false)
  register: deployment_infos

```

Pour expliquer l'utilisation du module ansible [kubernetes.core.k8s_info](https://docs.ansible.com/ansible/latest/collections/kubernetes/core/k8s_info_module.html). On attend que le retour de la commande `kubectl` reformatés en json atteigne des conditions.
Ces conditions sont ici checké toutes les 5 secondes (`wait_sleep`) et vont rendre une erreur si elles ne sont toujours pas bonne au bout de `350s`.

Voici ensuite ce qui est rendus entièrement par le `deployment_infos` dans la directive `register` qui permet à ansible de stocker ce **fact**.

Voici un exemple de retour pour un déploiement fonctionnel pour mieux comprendre.

```yaml
  "conditions": [
      {
          "lastTransitionTime": "2022-12-05T15:11:56Z",
          "lastUpdateTime": "2022-12-05T15:11:56Z",
          "message": "Deployment has minimum availability.",
          "reason": "MinimumReplicasAvailable",
          "status": "True",
          "type": "Available"
      },
      {
          "lastTransitionTime": "2022-12-05T15:11:46Z",
          "lastUpdateTime": "2022-12-05T15:11:56Z",
          "message": "ReplicaSet \"dex-5bd6ffdfd\" has successfully progressed.",
          "reason": "NewReplicaSetAvailable",
          "status": "True",
          "type": "Progressing"
      }
  ],

```

On remarque que le `status` à "True" signigie que nous avons réussi, que la `reason` indique qu'un replica à été créer. Un replica est une instance de pod dans un contexte ou l'on peut dupliquer les pod pour répartir la charge.

> **Note** la commande k8s_info donne tous les états par lesquels sont passé le pod.

Revenons à la déclaration de la boucle des manifests pour ajouter le plus important la boucle que l'on laise avec des null pour l'instant.
De plus le `when` permet de ne pas executer certains manifests propre à une autorité de certification interne.

[playbook/roles/kubeapps/tasks/manifests.yml](playbook/roles/kubeapps/tasks/manifests.yml#L10)

```yaml
---
- import_tasks: manifests.yml
  when: item.condition == True
  loop:
    - { src: ~, ns: ~ }
  tags: [kubeapps]
```

## Mise en place des communications réseau du cluster

Pour détailler sur cette partie essentielle à la bonne compréhension des applications distribuées sur kubernetes on parlera du dns.

Dans notre stack on a besoin de deux serveurs de nom, soit un interne **coredns** disponible uniquement dnas kubernetes et ses ressources et un serveur de nom global (qui peut être celui d'internet ou le réseau local).

### Dnsmasq pour résoudre les noms de domaines en local

L'objectif va être de pouvoir utiliser des domaines de test en local. Par exemple on veut utiliser dex.k3s.local pour accèder à l'authentifcation de notre cluster kubernetes.

L'installation sur **mac** est un peu différente de celle de Linux là voici pour commencer :

- `brew install dnsmasq` (si vous n'avez pas encore hombrew c'est [ici pour l'installer](https://brew.sh/index_fr))

- Créer le répertoire des configurations `mkdir -pv $(brew --prefix)/etc/`

- Préparer une variable pointant vers la config dnsmasq :

```sh
export DNSMASQ_CNF_DIR="$(brew --prefix)/etc/dnsmasq.conf"
```

Pour **Linux** :

- Commencer par désactiver le resolveur par défaut qui écoute sur le port `53`
```sh
sudo systemctl disable systemd-resolved
sudo systemctl stop systemd-resolved
```

- Surpprimer la configuration du résolveur par défaut

```sh
ls -lh /etc/resolv.conf
sudo rm /etc/resolv.conf
```

- Installer le package: `sudo apt install -y dnsmasq`

- Préparer une variable pointant vers la config dnsmasq pour l'étape suivante :

```sh
export DNSMASQ_CNF_DIR="/etc/dnsmasq.conf"
```

Pour **Linux** et **Mac** mettons ainsi tout en place :

- On précise bien que l'on veut résoudre toute les requète vers le domaine `.dev` avec l'adresse IP 127.0.0.1 : 

```sh
echo 'port=53' >> $DNSMASQ_CNF_DIR
echo 'address=/.k3s.local/127.0.0.1' >> $DNSMASQ_CNF_DIR
```

- On ajoute un resolveur avec :

```sh
sudo mkdir -v /etc/resolver
echo "nameserver 127.0.0.1" | sudo tee -a /etc/resolver/local
```

Redémarrer dnsmasq :

- Linux : `sudo systemctl restart dnsmasq`
- Mac : `sudo brew services restart dnsmasq`

Vérifier que tout fonctionne avec `scutil --dns` qui devrait donner :

```txt
resolver ...
  domain   : local
  nameserver[0] : 127.0.0.1
```

### Edition de coredns pour utiliser les url externes

Par défaut notre réseau privée, interne de kubernetes ne peux accèder à un serveur de nom autres que les plus répandus comme google (8.8.8.8) et cloudflare (1.1.1.1).

> **Note** : **Coredns** est l'outil qui fait office d'un des services coeur de kubernetes au même titre que ke kube-controller-manager par exemple. Ici il va donc s'agir du composant kube-dns.

On va donc changer la configuration par défaut de coredns en appliquant un simple manifest de type `ConfigMap`. Ce type permet de simplement définir des variables ou le contenu d'un fichier. Ici on va décrire le contenu d'un fichier Corefile qui va être monté au travers d'un volume au container coredns.

Voici la configuration par défaut :

[playbook/roles/kubeapps/templates/core-dns-config-crd.yml.j2](playbook/roles/kubeapps/templates/core-dns-config-crd.yml.j2)

```yaml

apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
          lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
          pods insecure
          fallthrough in-addr.arpa ip6.arpa
          ttl 30
        }
        prometheus :9153
        forward . 1.1.1.1
        cache 30
        loop
        reload
        loadbalance
    }
```

Le ingress **en local** n'est pas accessible depuis nos pods, nous allons donc avoir besoin de son ip pour l'associé au différents noms de domaines que l'on va utiliser. (dex.k3s.local / kubeapps.k3s.local).

Nous allons ainsi créer une nouvelles suite de tâche pour déduire les addresses réseau requises pour coredns.

On créer un fichier `tasks/internal-acme.yml` présentant ce code pour récupérer l'addresse ip de l'ingress à l'aide du module k8s_info d'ansible :

[playbook/roles/kubeapps/tasks/internal-acme.yml](playbook/roles/kubeapps/tasks/internal-acme.yml)

```yaml
---
- name: Prepare connection to localhost acme server
  when: kubeapps_internal_acme_network_ip | d(False)
  block:
  - name: Get Ingress service infos
    kubernetes.core.k8s_info:
      api_version: v1
      kind: Service
      name: traefik
      kubeconfig: /etc/rancher/k3s/k3s.yaml
      wait: yes
      namespace: kube-system
    register: ingress_infos

  - name: check ingress service infos available
    assert:
      that:
        - ingress_infos.resources | length > 0

  - name: Set localhost ip to find local acme
    set_fact:
      kubeapps_ingress_controller_ip: "{{ ingress_infos.resources[0].spec.clusterIP }}"

```

Maintenant la variable `kubeapps_ingress_controller_ip` est disponible et prête à être associé à une entrée dns. Cette variable nous sert à détécté que nous sommes bien en local

Venons en donc à la définitions des nom d'hôte des applications 

> Ils seront déployés dans les étapes suivantes donc n'essayer pas d'y accèder pour l'instant.

En sachant que le principe de base d'un dns est d'associé une adresse ip à un nom de domaine nous allons simplement associés les deux addresses `k3s.local` hériteé de notre dns local (dnsmasq) vers le ingress. Ainsi le traffic interne comme externe en direction de ces adresses arrivera bien au même endroit.

> **WARN** Nous faisons cela en réseau local mais si notre serveur est en ligne nous ne serons pas obligé de le faire car on passera par des dns (typoquement google, cloudflare...) capable de résoudre notre nom de domaines public et ses sous domaines.

[playbook/roles/kubeapps/templates/core-dns-config-crd.yml.j2](playbook/roles/kubeapps/templates/core-dns-config-crd.yml.j2#L28)

```conf
    {% set ingress_hosts_internals = [dex_hostname, kubeapps_hostname] | join(" ") -%}

    {{ ingress_hosts_internals }} {
      hosts {
        {{ kubeapps_ingress_controller_ip }} {{ ingress_hosts_internals }}
        fallthrough
      }
      whoami
    }
```

Enfin on configure l'addresse de notre acme interne pour que l'étape suivante puisse bien accèder à nos urls et que l'outil cert-manager puisse accèder à ce serveur acme.

```conf

    {{ kubeapps_internal_acme_host }} {
      hosts {
        {{ kubeapps_internal_acme_network_ip }} {{ kubeapps_internal_acme_host }}
        fallthrough
      }
      whoami
    }

```

Ainsi nous sommes prêt à faire fonctionner notre acme en local pour les tests. Cependant dans des environnement disponible sur internet nous n'allons pas activé cette partie. Nous réutilisons donc la variable `kubeapps_ingress_controller_ip` créer dynamiquement dans `internal-acme.yml` pour installer ou non le manifest kubernetes.

[playbook/roles/kubeapps/tasks/main.yml](playbook/roles/kubeapps/tasks/main.yml#L15)

```yaml
  loop:
    - src: core-dns-config-crd.yml
      condition: "{{ kubeapps_ingress_controller_ip is defined }}"
   
```

## Tls avec cert manager (et local)

Pour que notre plateforme fonctionne de manière suffisament sécurisé on adopte un principe zero-trust pour notre réseau. On va donc s'assurer que toutes les commucation entre nos service soient cryptées avec TLS (https). Pour cela on va faire appel à un ensemble d'outils de gestion des certificats dans un cluster kubernetes.

Ainsi [cert-manager](cert-manager.io)

#### Autorité locale

On va ici recourrir à une autorité de certification locale avec l'outil [pebble](https://github.com/letsencrypt/pebble). Il s'agit d'une implémentation de l'acme server dédiée au test. En effet il est recommandé d'utiliser un serveur acme de test pour éviter de saturer les quotas de let's encrypt.

Pour rappel Acme est un protocole embarquant une autorité de certification générant des certificats pour tls simplement au travers de plusieurs type de "challenges". On peut obtenir un certificats juste en ayant sont serveur http disponible sur le réseaux (ou internet) ou en ayant accès à l'édition des zones d'un serveur dns (en fonction du fournisseur).

#### Création de notre autorité avec docker et le playbook prepare de molecule

Ce playbook se lance avant le converge soit avant l'execution de notre rôle et lance un container docker sur notre machine. Comme précisé avant, le `network_mode` à host nous permet d'hérité des configuration de dnsmasq et permet d'accèder aux services sur l'autre container sur lequel on installe notre rôle.

[playbook/roles/kubeapps/molecule/default/prepare.yml](playbook/roles/kubeapps/molecule/default/prepare.yml)

```yaml
- name: Prepare
  hosts: localhost
  connection: local
  gather_facts: false
  no_log: "{{ molecule_no_log }}"
  collections:
    - community.docker
  tasks:
    - name: Start pebble container
      community.docker.docker_container:
        name: pebble
        image: "letsencrypt/pebble:latest"
        command: pebble -config /pebble/pebble-config.json
        state: started
        restart: True
        network_mode: host
        volumes:
          - "{{ playbook_dir }}/pebble:/pebble:ro"
      register: result
      until: result is not failed
      retries: 3
      delay: 10

    - name: Wait for pebble to start
      ansible.builtin.wait_for:
        host: localhost
        port: 15000
        delay: 5

```

> `playbook_dir` référence le dossier ou notre playbook molecule est lancé : `playbook/roles/kubeapps/molecule/default/`

Ensuite nous avons besoin de deux certificats racines pour initialiser notre autorité de certification. On les récupère sur le [projet github de pebble](https://github.com/letsencrypt/pebble/) directement avec cette commande.

> **Warning** Attention n'utiliser surtout pas pebble et ces certificats en production

```bash
mkdir -p playbook/roles/kubeapps/molecule/default/pebble
curl -L https://raw.githubusercontent.com/letsencrypt/pebble/main/test/certs/localhost/cert.pem > playbook/roles/kubeapps/molecule/default/pebble/cert.pem
curl -L https://raw.githubusercontent.com/letsencrypt/pebble/main/test/certs/localhost/cert.pem > playbook/roles/kubeapps/molecule/default/pebble/key.pem
```

Puis on créer le fichier de configuration de notre serveur acme :

[playbook/roles/kubeapps/molecule/default/pebble/pebble-config.json](playbook/roles/kubeapps/molecule/default/pebble/pebble-config.json)

```json
{
    "pebble": {
      "listenAddress": "0.0.0.0:14000",
      "managementListenAddress": "0.0.0.0:15000",
      "certificate": "/pebble/cert.pem",
      "privateKey": "/pebble/key.pem",
      "httpPort": 80,
      "tlsPort": 443,
      "ocspResponderURL": "",
      "externalAccountBindingRequired": false
    }
  }
```

Maintenant lorsque l'on lance `molecule test` nous executons dans l'ordre :

- Le playbook **create.yml** qui lance les plateformes définies dans molecule.yml (le ubuntu2004 pour tester notre rôle)
- Le playbook **prepare.yml** que l'on a entièrement créer pour lancer un pebble de test
- Le playbook **verify.yml** pour vérifier que l'on a bien lancer notre outils
- Le playbook **destroy.yml** qui supprime les containers de platforms
- Enfin le playboonk **cleanup.yml** que l'on créer en entier pour supprimer l'instance de pebble définie dans le prepare.

Voici le playbook **cleanup.yml** manquant :


[playbook/roles/kubeapps/molecule/default/cleanup.yml](playbook/roles/kubeapps/molecule/default/cleanup.yml)
```yaml
---
- name: Cleanup
  hosts: localhost
  connection: local
  gather_facts: false
  no_log: "{{ molecule_no_log }}"
  collections:
    - community.docker
  tasks:
    - name: Destroy pebble instance(s)
      docker_container:
        name: pebble
        state: absent
      when: {{ lookup('env', 'MOLECULE_CLEANUP') | boolean | d(false) }}

```

> On choisi de laisser par défaut le container pebble lancé pour pouvoir le relancer avec `molecule converge` et ne pas avoir à le relancer à chaque fois. Cependant dans un environnement de CI/CD on peut vouloir supprimer le container après chaque test.

### Cert-manager

Venons en à l'élement central de notre stack, cert-manager. Il va nous permettre de créer des certificats pour nos services kubernetes.

Cert-manager permet d'utiliser le protocoles acme embarqué dans des outils comme pebble. Il permet de créer des certificats pour des services http, dns et mTLS.
On l'utilisera avec pebble pour distribuer les certificats vers les **ingress** avec des ressources secrets contenant respectivement le certificat et la clé de déchiffrage. 

Pour résumer en schéma :

![stack](./images/ingress-cert-manager.jpg)

Tout d'abord on ajoute les variables et puis des constantes dans le fichier vars.yml que l'on utilise dans un souci de clarté :

Voici donc des constantes que l'on ne pas probablement jamais avoir besoin de changer (toutefois on pourrait le faire si besoin avec un `set_fact` mais ce n'est pas très propre)

[playbook/roles/kubeapps/vars/main.yml](playbook/roles/kubeapps/vars/main.yml)

```yaml
# vars file for role-kubeapps
kubeapps_k8s_ingress_class: traefik
letsencrypt_staging: https://acme-staging-v02.api.letsencrypt.org/directory
letsencrypt_prod: https://acme-v02.api.letsencrypt.org/directory 

letsencrypt_envs:
  staging: "{{ letsencrypt_staging }}"
  prod: "{{ letsencrypt_prod }}"

letsencrypt_envs_ca_certs:
  staging: https://letsencrypt.org/certs/staging/letsencrypt-stg-root-x1.pem

```

> `letsencrypt_staging` et `letsencrypt_prod` sont anticipé pour l'utilisation de cert-manager en production.

> `letsencrypt_envs_ca_certs` est l'url que l'on ajoutera dans les containers pour activer tls entre eux sur un environnement de test en ligne.

Les défauts qui utilise les variables prédéfinie précédemment :

[playbook/roles/kubeapps/defaults/main.yml](playbook/roles/kubeapps/defaults/main.yml)

```yaml
---
# Kubeapps internal acme server
kubeapps_internal_acme_network_ip: ~
kubeapps_internal_acme_host: acme-internal.k3s.local

cert_manager_letsencrypt_env: prod
cert_manager_namespace: cert-manager
cert_manager_acme_url: "{{ letsencrypt_envs[cert_manager_letsencrypt_env] }}"
cert_manager_staging_ca_cert_url: "{{ letsencrypt_envs_ca_certs[cert_manager_letsencrypt_env] | d(none) }}"
cert_manager_email: ""
cert_manager_private_key_secret: test_secret
```

Que l'on surcharge tout de suite dans le playbool **converge.yml** :

[playbook/roles/kubeapps/molecule/default/converge.yml](playbook/roles/kubeapps/molecule/default/converge.yml#L10)

```yaml
    cert_manager_acme_url: https://{{ kubeapps_internal_acme_host }}:14000/dir
    cert_manager_staging_ca_cert_url: https://localhost:15000/roots/0

```

> `cert_manager_acme_url` doit toujours utilisé l'entrée dns que l'on a choisie juste avant et qui est par défaut `acme.k3s.local`. un nom d'hôte que l'on a choisi pour l'usage local de cert-manager.

> **WARN** Attention en production ou recette l'addresse email `cert_manager_email` doit appartenir à un domaine valide (gmail, hotmail, etc...)

#### Mettons en place une bonne pratique

L'objectif est d'éviter des comportement non souhaité lors de l'utilisation de cert-manager et donc de ne pas lancer l'installation de la suite des tâches si il manque certaines configuration. Cert-manager est un composant coeur dans notre stack car il distribue les certificats pour certains service embarquant des protocoles d'authentification. Nous ne pourrons pas utiliser ces services si il n'y a pas de certificats et d'encryption des échanges en TLS (v1.2+).

On créer donc un fichier `check.yml` dans le dossier `tasks` de notre rôle. Ce fichier contient des tâches de vérification de variable configuration.

[playbook/roles/kubeapps/tasks/checks.yml](playbook/roles/kubeapps/tasks/checks.yml)

```yaml
- name: check email when cert-manager
  assert:
    that:
      - cert_manager_email | default(false)

```

Puis on active ceci en premier dans le fichier wrapper `main.yml` :

[playbook/roles/kubeapps/tasks/main.yml](playbook/roles/kubeapps/tasks/main.yml#L3)

```yaml
- import_tasks: checks.yml
  tags: [kubeapps]

```

**Puis on installe cert-manager** avec le module helm chart de k3s.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: {{ cert_manager_namespace }}
---
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: cert-manager
  namespace: kube-system
spec:
  chart: cert-manager
  targetNamespace: {{ cert_manager_namespace }}
  repo: https://charts.jetstack.io
  valuesContent: |-
    installCRDs: true
```

`installCRDs: true` permet de rendre disponible des nouveaux types de manifests propre à l'outil, voici la commande pour vérifier qu'ils sont bien installés :

```bash
kubectl get crd
# Give
orders.acme.cert-manager.io            
certificates.cert-manager.io            
certificaterequests.cert-manager.io    
challenges.acme.cert-manager.io
clusterissuers.cert-manager.io
issuers.cert-manager.io
```

Ensuite créeons notre **issuer** qui va s'occuper de tout le cycle de vie d'un certificat demandé par un ingress au travers de l'annotation.

```yaml
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt-acme-issuer
```

Voici le manifest de l'issuer de type acme 

> **Note** il existe d'autre types d'issuer pour d'autre protocoles come vault pki, ca, etc...

```yaml
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-acme-issuer
spec:
  acme:
    skipTLSVerify: {{ cert_manager_is_internal }}
    email: {{ cert_manager_email }}
    server: {{ cert_manager_acme_url }}
    privateKeySecretRef:
      name: acme-account-key
    solvers:
    - selector: {}
      http01:
        ingress:
          class: {{ kubeapps_k8s_ingress_class }}

```

> **Note** Vu que l'on passe par l'ingress pour injecter les point d'accès des challenge acme, il faut bien configuré l'issuer avec la bonne classe d'ingress.

> **Note** kind: `ClusterIssuer` permet de créer un issuer qui sera disponible dans tout le cluster. À l'inverse un `Issuer` est disponible dans un seul namespace.

Nous voilà prêt il ne reste que à appeler la création du manifest dans notre fichier wrapper `main.yml` :

[playbook/roles/kubeapps/tasks/main.yml](playbook/roles/kubeapps/tasks/main.yml#L16)

```yaml

- include_tasks: manifests.yml
  # ...
  loop:
    # ...
    - { src: cert-manager-chart-crd.yml, deploy:  "{{ cert_manager_namespace }}" }

```

Tout cela ne va cependant pas être suffisant dans le cas du mTLS car on va avoir besoin de faire confiance à notre autorité de certification.

### Faire confiance à notre autorité de certification (CA)

On a deux endroits où l'on va faire confiance à notre autorité de certification.

- Sur notre machine dans les différents pods ou mTLS 
- Sur le navigateur

#### Sur notre machine dans les différents pods ou mTLS 

Les serveurs acceptent les certificats de notre autorité de certification et se font donc suffisament confiance entre eux pour établir une connection TLS.

Pour que en interne nos serveur se fassent confiance nous avons besoin de récupérer le certificat racine de notre autorité de certification et de l'ajouter dans le trust de nos serveurs.

Voici la directive ansible :

[playbook/roles/kubeapps/tasks/internal-acme.yml](playbook/roles/kubeapps/tasks/internal-acme.yml#L17)

```yaml

- name: Download certificate file
  uri:
    url: "{{ cert_manager_staging_ca_cert_url }}"
    validate_certs: "{{ kubeapps_internal_acme_network_ip is none }}"
    return_content: True
  register: ca_file

```

[playbook/roles/kubeapps/tasks/internal-acme.yml](playbook/roles/kubeapps/tasks/internal-acme.yml#L13)

```yaml
- set_fact:
    kubeapps_internal_acme_ca_content: "{{ ca_file.content }}"

```

[playbook/roles/kubeapps/tasks/main.yml](playbook/roles/kubeapps/tasks/main.yml#L13)

```yaml
- import_tasks: internal-acme.yml
  when: cert_manager_is_internal
  tags: [kubeapps]
```

Nous introduisons ici la variable `cert_manager_is_internal` qui nous permet de savoir si nous utilisons un acme spécial autre celui que le letsecrypt de production. Effectivement les acme locaux et staging ne sont pas référencés comme digne de confiance sur l'internet global.

[playbook/roles/kubeapps/tasks/main.yml](playbook/roles/kubeapps/tasks/main.yml#L14)

```yaml
cert_manager_is_internal: "{{ cert_manager_staging_ca_cert_url is not none }}"

```

> L'idée est que si un url fournissant un certifiat est donné avec `cert_manager_staging_ca_cert_url` alors on considère que l'on est en environnement interne.

Nous avons alors besoin de plusieurs choses pour importer notre certificat racine dans le "truststore" de nos serveurs.

Une ressource kube configmap (ou secret) pour stocker le certificat racine que l'on a récupéré dans les étapes précédentes avec le module ansible `slurp`.

[playbook/roles/kubeapps/templates/trust-bundle-config-crd.yml.j2](playbook/roles/kubeapps/templates/trust-bundle-config-crd.yml.j2)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: acme-internal-root-ca
  namespace: "{{ cert_manager_namespace }}"
data:
  ca.crt: |
    {{ kubeapps_internal_acme_ca_content | indent(4) }}

```

> `indent` sert à rajouter les espace à chaque lignes du certificat pour qu'il soit bien formatté dans le fichier yaml.

**Cependant** nous remarquon avec `kubectl get cm -A` que la ressource n'est présente que dans le namespace `cert-manager` or nous avons besoin de la récupérer dans les autres namespaces.

C'est pourquoi nous allons utiliser un module `trust-manager` fourni par jetstack pour partager cette ressource.

Pour commencer nous allons installer le helm chart de `trust-manager` avec le template `playbook/trust-manager.yml.j2` :

[playbook/roles/kubeapps/templates/trust-manager-chart-crd.yml.j2](playbook/roles/kubeapps/templates/trust-manager-chart-crd.yml.j2)
```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: trust-manager
  namespace: kube-system
spec:
  version: 0.3.0
  chart: trust-manager
  targetNamespace: {{ cert_manager_namespace }}
  repo: https://charts.jetstack.io

```

> Warning : on fixe bien la version du chart car l'équipe de développement précise qu'ils apporterons des changements non rétrocompatible dans les prochaines versions.

Puis on ajoute dans après notre configmap le trust-bundle pour partagé notre configmap sous le nom `acme-internal-ca-share` avec comme sous variable le fichier `ca.crt`:

```yaml
---
apiVersion: trust.cert-manager.io/v1alpha1
kind: Bundle
metadata:
  name: acme-internal-ca-share
spec:
  sources:
  - configMap:
      name: "acme-internal-root-ca"
      key: "ca.crt"
  target:
    configMap:
      key: "ca.crt"

```

Ensuite, **il est essentiel** d'appeler dans l'ordre tous ces manifests que l'on vient de créer :

> On les lance bien après l'installation et configuration de notre issuer `cert-manager` pour éviter des erreurs de dépendances.

[playbook/roles/kubeapps/tasks/main.yml](playbook/roles/kubeapps/tasks/main.yml#L17)
```yaml
    - src: trust-manager-chart-crd.yml
      deploy: trust-manager 
      ns: "{{ cert_manager_namespace }}"
      condition: "{{ cert_manager_is_internal }}"
    - src: trust-bundle-config-crd.yml
      condition: "{{ cert_manager_is_internal }}"
```

Une fois cette configuration stocké nous allons pouvoir l'injecter dans les pods avec des `volumes`.

Ces voluemes sont des espace de stockage qui seront monté dans les pods et qui seront accessible par les containers.

Voici les objets volumes définie dans le fichier **vars.yml** de notre role kubeapps afin de le réutiliser sur plusieurs pods :

[playbook/roles/kubeapps/vars/main.yml](playbook/roles/kubeapps/vars/main.yml#L7)

```yaml
# Mounted in acme internal
kubeapps_internal_acme_ca_in_volume_crt: /etc/ssl/certs/acmeca.crt
kubeapps_internal_acme_ca_extra_volumes: []
kubeapps_internal_acme_ca_extra_volumes_mounts: []

```

> **Note** `/etc/ssl/certs/` est le répertoire par défaut des certificats sur les images linux, ils sont très souvent supportés par les framework et langages de programmation. Ainsi on fera confiance à toute requètes https vers un serveur configurés avec un certificat signé par celle-ci.

Voici un exemple d'utilisation des volumes dans kubernetes :

Import du volume pour le rendre disponible au montage :

```yaml
podname:
  extraVolumes:
    {{ kubeapps_internal_acme_ca_extra_volumes | to_nice_yaml | indent(4) }}

```

Montage du volume dans le container :

```yaml
podsubcontainer:
  extraVolumeMounts:
    {{ kubeapps_internal_acme_ca_extra_volumes_mounts | to_nice_yaml | indent(4) }}
```

Les volumes sont **vide par défaut**, on les renseigne seulement à la fin de la tâche internal-acme lancée en mode cert-manager interne. Voici la suite du `set_fact` (l.25) dans cette tâche :

[playbook/roles/kubeapps/tasks/internal-acme.yml](playbook/roles/kubeapps/tasks/internal-acme.yml#L25)

```yaml
    kubeapps_internal_acme_ca_extra_volumes:
    - name: acme-internal-ca-share
      configMap: 
        name: acme-internal-ca-share
    kubeapps_internal_acme_ca_extra_volumes_mounts:
    - name: acme-internal-ca-share
      mountPath: "{{ kubeapps_internal_acme_ca_in_volume_crt }}"
      subPath: ca.crt

```

#### Sur notre navigateur :

Une autorité de certification est toujours initiée à partir d'une paire cryptographique faite d'une clé privée et d'un certificat contenant une clé publique. Comme pour d'autres protocole comme ssh ou même etherum il faut accepter le certificat racine de l'autorité contenant la clé publique.

Vous pouvez le récupérer avec cette commande :

```bash
curl -k https://localhost:32444/roots/0 > ~/Downloads/pebble-ca.pem
```

**Mac :**

- Open Keychain Access
- File > import items...
- Select ~/Downloads/pebble-ca.pem
- Right click on minica root ca choose get info
- Open Trust and select Always Trust on When using this certificate

**Sur Linux** :

```
sudo cp ~/Downloads/pebble-ca.pem /usr/local/share/ca-certificates/pebble-ca.pem
sudo chmod 644 /usr/local/share/ca-certificates/pebble-ca.pem
sudo update-ca-certificates
```

***Relancez la page sur votre navigateur**

### H. Une authentification et des habilitations fines pour kubeapps

Il est inclu dans kubernetes deux façons d'authentifier les utilisateurs au cluster et ses resources api (`services`, `pods`, `secrets`...) :

- Les Service accounts utilisés pour authentifié des processus qui se lancent dans les pods. Ils s'utilisent avec un simple token et des droits rattachés.

- Users et Groups (comme pour linux). Ces resources sont créer implicitement par un client open id connect fourni sous réserve d'activation par kubernetes.
On optera pour cette méthode en utilisant comme serveur open id : **dex** idp qui consomme plusieurs fournisseurs d'accès externes (ou interne).


### 1. Configuration de notre organisation github et application oauth

Créer une nouvelle organisation [ici](https://github.com/account/organizations/new) :

- Sélectionner le free plan
- Choisissez un nom à l'organisation
- Renseignez votre email
- Cocher bien que elle vous appartient (rattaché à votre pseudo github)

> On peut créer une équipe particulière dans notre organisation qui pourra avoir accès à kubeapps. Le Lien vers le formulaire de création ressemble à ça : https://github.com/orgs/nom-de-ton-organisation/new-team.

Nommez les comme vous voulez puis ajoutez la variable dans votre playbook de test (non conseillé en production, utilisez plutôt ansible-vault) :

[playbook/roles/kubeapps/molecule/default/converge.yml](playbook/roles/kubeapps/molecule/default/converge.yml#L14)

```yaml
    dex_github_client_org: "esgi-lyon"
    dex_github_client_team: "ops-team-test"
```

#### Créer l'application github

[créer votre application ici](https://github.com/organizations/<my-org>/settings/applications/new)

Configuré la comme ceci **pour l'instant** en utilisant les url en local qui ne fonctionnerons pas (pas de tls activé / ni online)

- Application name : `kubeapps-test`
- Homepage URL : `https://kubeapps.k3s.local`
- Authorization callback URL : `https://dex.k3s.local/callback`

Ensuite noté bien votre **Client Id** et générer un nouveau **Client secret** en plus.

#### Encrypter les secrets de application github

Nous allons crypter les Informations dangereuses dans un vault ansible que l'on pourra créer avec :

Dans votre rôle `playbook/roles/kubeapps`

```bash
ansible-vault create --vault-password-file $HOME/.ansible/.vault molecule/default/group_vars/molecule/secrets.yml
```

Renseigner un mot de passe dans le fihcier `$HOME/.ansible/.vault`.

> **Warning** : Ce mot de passe est utilisé pour décrypter les secrets de votre playbook de test. Il est donc important de le garder secret d'où une localisation à l'extérieure du repo.

> **Warning** Il est aussi recommandé de le stocker en double dans un gestionnaire de mot de passe ou autre gestionnaire de secret perfectionné (Github action, hashicorp vault...)

Vous devrez ensuite renseigner ces secrets afin de cacher les informations sensibles dans votre playbook de test.

[playbook/roles/kubeapps/molecule/default/group_vars/molecule/secrets.yml](playbook/roles/kubeapps/molecule/default/group_vars/molecule/secrets.yml)

```yaml
cert_manager_email: test4@k3s.local

dex_github_client_id: "my-client-id-from-github-oauth-app"
dex_github_client_secret: "my-client-secret-from-github-oauth-app"

```

Si besoin vous pouvez éditer le fichier avec la commande suivante :

```bash
ansible-vault edit molecule/default/group_vars/molecule/secrets.yml --vault-password-file $HOME/.ansible/.vault
```

> Note : les **github secrets** de la CI/CD de github [https://github.com/domaine/repo/settings/secrets/actions]() peuvent être une localisation idéale.

Vous aviez créer un mot de passe et déplacer le dans un fichier `${HOME}/.ansible/.vault` pour pouvoir ouvrir les fichiers de secrets cryptés.

```bash
echo 'my-pass' > $HOME/.ansible/.vault
```

> Warning : en bash `>` écrase le fichier et `>>` ajoute à la fin du fichier

Puis on configure molecule pour utiliser le fichier de mot de passe et le groupe de variable **`molecule`** qui contient nos secret. Il est implicitement définie quand on créer le dossier `group_vars/molecule`:

Dans votre configuration de platforme de test molecule `node-0` :

[playbook/roles/kubeapps/molecule/default/molecule.yml](playbook/roles/kubeapps/molecule/default/molecule.yml#L12)

```yaml
    groups:
      - molecule
```

Puis on configure le provisioner ansible pour utiliser le fichier de mot de passe :

[playbook/roles/kubeapps/molecule/default/molecule.yml](playbook/roles/kubeapps/molecule/default/molecule.yml#L22)

```yaml
provisioner:
  name: ansible
  config_options:
    defaults:
      vault_password_file: ${HOME}/.ansible/.vault
```

Voilà, maintenant molecule importe les secrets et les rend disponible dans les variables ansible.

#### Installation et configuration

D'abord comme vu précédemment avec cert-manager on créer les variables par défaut requises par dex :

[playbook/roles/kubeapps/defaults/main.yml](playbook/roles/kubeapps/defaults/main.yml)

D'abord des informations globales comme l'espace de nom kubernetes et l'url auquel on peut accèder au service.

```yaml
# HelmChart Custom Resource Definition for dex oidc connector
dex_namespace: dex
dex_hostname: dex.k3s.local
```

Ensuite on précise les informations de connexion à github ainsi que les celles qui permettrons au client de notre openid de se connecter. On laisse ces informations à null dans un but de documentation.

> On prend un raccourci avec le secret mais dans l'inventaire ansible final on renseignera des secrets plus sécurisées.

```yaml
dex_client_id: kubeapps
dex_client_secret: ~
dex_github_client_id: ~
dex_github_client_secret: ~
dex_github_client_org: ~
dex_github_client_team: ~
```
> **INFO** Le client open id est ici kubeapps. Pour résumé après ce schéma, kubeapps se sert du **claim open id** `groups` (qui aura ici comme valeur `esgi-lyon:ops-team`) renvoyé par dex pour accèder aux ressources du cluster autorisées par son rôle.

Voici un schéma pour imager comment ce claim open id va servir à sécuriser l'attribution des droits en plus de la connection au cluster.

```
---|   |--------|        |------- |                      |----------|
   |   |kubeapps|-- ask->| dex    |--convert request---->| Github   |
k3s|<--|        |<-------| openid |                      | oauth2   |
---|   |--------|--------|--------|<-esgi-lyon:ops-team--|----------|
                         
```

> **WARN** Le `dex_client_secret` par défaut n'est pas du tout sécurisé et doit être changé en production

Ensuite, définissons un manifest utilisant helm pour installer facilement dex sur le cluster kubernetes. Implicitement seront créer des fichiers d'attributions de droit au cluster, le fichier de déploiement des pod et les services exposants des noms et addresses dans le cluster.

[playbook/roles/kubeapps/templates/dex-chart-crd.yml.j2](playbook/roles/kubeapps/templates/dex-chart-crd.yml.j2)

On commence par créer le namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: {{ dex_namespace }}
```

Puis on installe le chart helm de dex comme d'habitude avec ce genre de manifest :

```yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: dex
  namespace: kube-system
spec:
  chart: dex
  targetNamespace: {{ dex_namespace }}
  repo: https://charts.dexidp.io
```

Dans le `valuesContent` nous allons renseigner trois prncipaux objets de configuration :

**`config`** qui configure l'application web dex avec :
  - Le `issuer` est l'url de base de dex. Il est utilisé pour construire les urls de redirection et de callback.
  - Le connecteur github
  - Les informations de stockage, 
  - L'hôte et le port interne sur lequel le serveur web écoute et 
  - Le client openid pour donner le droit à kubeapps de consommer l'authentification de dex

Voici la configuration qui réutilise les variables de notre application oauth github et les credentials définies dans les defaults et le playbook converge.yml :

```yaml
  valuesContent: |-
    config:
      issuer: "https://{{ dex_hostname }}"
      web:
        http: 0.0.0.0:5556
      storage:
        type: kubernetes
        config:
          inCluster: true
      connectors:
      - type: github
        id: github
        name: GitHub
        config:
          clientID: '{{ dex_github_client_id }}'
          clientSecret: '{{ dex_github_client_secret }}'
          redirectURI: "https://{{ dex_hostname }}/callback"
          orgs:
          - name: '{{ dex_github_client_org }}'
            teams: 
            - '{{ dex_github_client_team }}'
      oauth2:
        skipApprovalScreen: true
      staticClients:
      - id: "{{ dex_client_id }}"
        redirectURIs:
        - 'https://{{ kubeapps_hostname }}/oauth2/callback'
        name: 'Kubeapps'
        secret: "{{ dex_client_secret }}"
```

Ensuite on configure le ingress pour que dex soit accessible depuis l'extérieur du cluster. 

Pour cela on donne une listes d'hôtes pour lesquels les requètes amènerons bien au **service** dex (port 5556).

Un **servive** kubernetes est toujours créer en accompagnement d'un **déploiement** et se voit automatiquement attribué une addresse ip interne. Ici le service sera de type clusterIp.

Voici la commande pour consulter le service et son adresse ip :

```bash
kubectl get svc -n dex -o yaml
```

qui nous donne le manifest :

```yaml
kind: Service
  metadata:
    annotations:
      meta.helm.sh/release-name: dex
      meta.helm.sh/release-namespace: dex
    creationTimestamp: "2022-12-10T17:12:50Z"
    labels:
      app.kubernetes.io/instance: dex
      app.kubernetes.io/managed-by: Helm
      app.kubernetes.io/name: dex
      app.kubernetes.io/version: 2.35.3
      helm.sh/chart: dex-0.12.1
    name: dex
    namespace: dex
    resourceVersion: "1159"
    uid: c88f2dcb-85d0-4f74-bdeb-4e53b964d5b5
  spec:
    clusterIP: 10.43.12.126
    clusterIPs:
    - 10.43.12.126
    ipFamilies:
    - IPv4
    ipFamilyPolicy: SingleStack
    ports:
    - appProtocol: http
      name: http
      port: 5556
      protocol: TCP
      targetPort: http
    - appProtocol: http
      name: telemetry
      port: 5558
      protocol: TCP
      targetPort: telemetry
    selector:
      app.kubernetes.io/instance: dex
      app.kubernetes.io/name: dex
    sessionAffinity: None
    type: ClusterIP
  status:
    loadBalancer: {}
```

On utilise ici le certificat délivré par cert-manager au travers d'un secret `{{ dex_hostname }}-tls` intermédiaire automatiquement créer par l'issuer configuré avec `cert-manager.io/cluster-issuer: letsencrypt-acme-issuer`.

[playbook/roles/kubeapps/templates/dex-chart-crd.yml.j2](playbook/roles/kubeapps/templates/dex-chart-crd.yml.j2#L44)

```yaml  
    ingress:
      enabled: true
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt-acme-issuer
        kubernetes.io/ingress.class: "{{ kubeapps_k8s_ingress_class }}"
        traefik.frontend.passHostHeader: "true"
        traefik.ingress.kubernetes.io/router.tls: "true"
      hosts:
      - host: {{ dex_hostname }}
        paths:
          - path: /
            pathType: ImplementationSpecific
      tls:
        - secretName: {{ dex_hostname }}-tls
          hosts:
            - {{ dex_hostname }}
```

> Note: `traefik.ingress.kubernetes.io/router.tls: "true"` est nécessaire pour que traefik redirige les requêtes http vers https.

#### Et enfin l'installation de kubeapps

Commencons par construire notre manifest. Pour cela nous avons besoin de définir plusieurs variables pour rendre configurable l'utilisation de notre rôle :

Dans [playbook/roles/kubeapps/defaults/main.yml](playbook/roles/kubeapps/defaults/main.yml) on aura donc :

- `kubeapps_namespace` pour définir le namespace à créer et sur lequel on déploie kubeapps

- `kubeapps_user` définit à `ansible_user` une variable censé être définie dans un playbook de production dans le fichier host. Par défaut on le met à `root` si la variable n'existe pas.

- `kubeapps_hostname` pour choisir à quel url sera disponible kubeapps.

> Par défaut kubeapps sera disponible sur `kubeapps.k3s.local`

[playbook/roles/kubeapps/defaults/main.yml](playbook/roles/kubeapps/defaults/main.yml#L22)

```yaml
---
# HelmChart Custom Resource Definition for kubeapps variables
kubeapps_namespace: kubeapps
kubeapps_user: "{{ ansible_user | default('root') }}"
kubeapps_hostname: kubeapps.k3s.local
```

Ensuite nous allons utiliser toutes ces variables dans un manifest kubernetes qui inclus deux resources. Un namespace et une définition de dépendance helm avec sa configuration.

> **Note** sur le templating jinja dans la moustache `{{}}` rajouter un `-` signifie que l'on ignore le format du côté ou l'on utilise. Par exemple un retour à la ligne (colonne 0) sera ignorer pour `-}}`.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: {{ kubeapps_namespace }}
---
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: kubeapps
  namespace: kube-system
spec:
  chart: kubeapps
  targetNamespace: {{ kubeapps_namespace }}
  repo: https://charts.bitnami.com/bitnami
  valuesContent: |-
    ingress:
      tls: true
      enabled: true
      hostname: "{{ kubeapps_hostname }}"
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt-acme-issuer
        kubernetes.io/ingress.class: "{{ kubeapps_k8s_ingress_class }}"
        traefik.frontend.passHostHeader: "true"
        traefik.ingress.kubernetes.io/router.tls: "true"

```

> **Note** On configure le ingress directement dans la définition helm tout en précisant bien que l'on utilise traefik en sachant que par défaut il est souvent utilisé `nginx` comme cntroller ingress

Nous allons lancer la commande de templating grâce au module `template` de la collection **builtin** (fonctionnalités inclus par défaut) de ansible.

Celle ci va faire le remplacement des variables utilisées dans les moustaches `{{}}` et placer le fichier au bon endroit dans notre machine invité. Ici il se trouvera dans notre container `node-0` dans le répertoire `/var/lib/rancher/k3s/server/manifests/kubeapps-chart-crd.yml`


[playbook/roles/kubeapps/tasks/main.yml](playbook/roles/kubeapps/tasks/main.yml#L23)
```yaml
    - src: kubeapps-chart-crd.yml
      deploy:  "{{ kubeapps_namespace }}"

```

Pour vérifier que les pods de kubeapps sont bien prêt :

- On regarde d'abord si la tâche `helm` a bien pu se finir

```bash
kubectl get po -n kube-sysem
```
Devrait donné `helm-install-kubeapps-4cdf8` avec status `COMPLETED`

##### Ensuite connection à dex Idp pour s'authentifier avec github

Pour ajouter la couche d'authentification kubeapps fait appel à la solution [oauth2-proxy](https://oauth2-proxy.github.io/oauth2-proxy/docs/configuration/oauth_provider#github-auth-provider). Il s'agit donc d'un reverse proxy qui redirige le trafic http d'un client authentifier à un serveur implémentant oauth2 (et implicitement opend id connect) avant de permettre la connection à kubeapps.

Cette authentification est associé à un cookie converti en base64 à partir d'un secret que l'on définie avec une commande simple : 

```bash
echo "not-good-secret" | base64
```

> [playbook/roles/kubeapps/defaults/main.yml](playbook/roles/kubeapps/defaults/main.yml#L30) **ligne 18 jusqu'à la fin**

```yaml
# ...
# Cookie secret
kubeapps_oauth_proxy_cookie_secret: bm90LWdvb2Qtc2VjcmV0Cg==
```

`--oidc-issuer-url` est obligatoire quand l'on utilise pas un fournisseur d'authentification pré-concu comme github, gitlab, google, etc. Il faut donc le définir avec l'url de dex pour qu'il soit bien consommé par le client openid de oauth2-proxy.

> Note : Pour consulter la configuration d'open id vous pouvez ouvri l'url [dex.k3s.local/.well-known/openid-configuration](https://dex.k3s.local/.well-known/openid-configuration) dans votre navigateur.

Ensuite on réutilise nos secrets de **dex idp** pour créer et configurer l'accès du container `authProxy` à opend id dans le pod `frontend` de kubeapps.

[playbook/roles/kubeapps/templates/kubeapps-chart-crd.yml.j2](playbook/roles/kubeapps/templates/kubeapps-chart-crd.yml.j2#L28) **ligne 28**
```yaml
    authProxy:
      enabled: true
      provider: oidc
      clientID: "{{ dex_client_id }}"
      clientSecret: "{{ dex_client_secret }}"
      cookieSecret: '{{ kubeapps_oauth_proxy_cookie_secret }}'
      cookieRefresh: 5m
      extraFlags:
        - --oidc-issuer-url=https://{{ dex_hostname }}
```

Par défaut si on relance notre test molecule nous n'aurons pas d'activation de l'authentificaiton avec github. Nous allons donc pour cette fois faire un test manuelle de celle-ci car elle dépend de configuration propre à une production soit tls activé que kubeapps soit disponible en ligne. (obligation en terme de sécurité de oauth2 / github)

Enfin maintenant que notre chart est déployé avec un combo **oauth-proxy** / **dex** fonctionnel nous allons configurer le contrôle d'accès à l'administration du cluster. Nous utilisons pour cela une ressource `ClusterRoleBinding` pour lier un groupe d'une organisation github à un rôle `cluster-admin` qui lui donne tous les droits sur le cluster.

[playbook/roles/kubeapps/templates/kubeapps-chart-crd.yml.j2](playbook/roles/kubeapps/templates/kubeapps-chart-crd.yml.j2)

```yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kubeapps-github-teams
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: Group
    name: "{{ dex_github_client_org }}:{{ dex_github_client_team }}"

```

Nous voilà prêt à tester notre déploiement de kubeapps. Nous allons donc lancer notre test molecule et attendre son éxecution :

```bash
molecule test --destroy never
```

Une fois l'éxecution terminé, il faut attendre quelques secondes pour que tous les pods soient bien prêts. On peut alors se connecter à l'interface web de kubeapps en se connectant à l'adresse [https://kubeapps.k3s.local](https://kubeapps.k3s.local) et en utilisant notre compte github nous allons pouvoir nous connecter.

Voici la page de login attendue :

![kubeapps](./images/kubeapps-auth.png)

Et voici la page de dashboard de kubeapps une fois connecté :

![kubeapps](./images/kubeapps-ready.png)

### Mise en place des tests de kubeapps

Grâce au module ansible [k8s info](https://docs.ansible.com/ansible/latest/collections/kubernetes/core/k8s_info_module.html) on test les pods centraux de kubeapps. Si ces pod sont bien en état `ready` c'est que kubeapps est prêt

> On note qu'il est important de préciser à `k8s_info` la localisation kubeconfig qui se trouve à un endroit un peu exotique avec k3s. Cette config comporte des informations utilisateur et des certificats permettant de se connecter sur le cluster.

> [playbook/roles/kubeapps/molecule/default/verify.yml](playbook/roles/kubeapps/molecule/default/verify.yml#L18)
```yaml
    - name: Get Kubeapps service infos
      kubernetes.core.k8s_info:
        api_version: v1
        kind: Pod
        label_selectors:
        - app.kubernetes.io/component = frontend
        kubeconfig: /etc/rancher/k3s/k3s.yaml
        namespace: kubeapps
      register: kubeapps_infos

    - ansible.builtin.set_fact:
        containers_statuses: "{{ (kubeapps_infos.resources | last).status.containerStatuses }}"

    - ansible.builtin.debug:
        msg: "{{ containers_statuses | map(attribute='name') }}"

    - name: Assertions on service kubeapps 
      assert:
        that:
          - kubeapps_infos.resources | length > 0
          - containers_statuses | selectattr('ready', 'equalto', true) | list | count == 2

```

Si votre playbook est déjà passé en entier un `molecule verify` va suffire pour jouer le playbook `verify.yml`.

Vous devriez voir passer les assertions et les autres tâches.

Pour autant vous ne verrez pas encore de retour de ce type tout simplement par ce que le code n'est pas complet.

```
node-0                     : ok=15 ...
```

### J. Playbook et inventaire final

Nous allons adapter le rôle en vue de cette fois ci le rendre utilisable par un playbook de pré-production.

Nous allons créer le fichier `site.yaml` (dans le dossier `playbook/`) qui va se charger avec la commande `ansible-playbook` de lancer les rôles dans le bon ordre sur les machines.

Cette étape servira pour utiliser le playbook dans la [partie 2](#2-créer-une-première-image-virtuelle-pour-le-test) avec packer

> [playbook/site.yaml](playbook/site.yaml)
```yaml
---
- hosts: all
  gather_facts: True
  become: True
  roles:
    - role: roles/kubeapps

```

Ensuite on créer notre inventaire pour azure dans un dossier `playbook/inventories/azure/`. Uun inventaire ansible est constitué d'un groupe de variables (dossier `group_vars`) et d'un fichier `hosts` qui va contenir les machines sur lesquelles on va jouer le playbook.

```bash
mkdir -p playbook/inventories/azure/group_vars
```

Ces variables de groupes font appel à un plugin `lookup` permettant de lire les secrets d'une ressource keyvault que l'on configurera dans la partie terraform.

On peut ajouter l'installation de la collection dans les requirements du playbook si ce n'est pas déjà fait.

[playbook/inventories/azure/group_vars/all.yml](playbook/inventories/azure/group_vars/all.yml)

```yaml
---
cert_manager_email: "{{ lookup(
  'azure.azcollection.azure_keyvault_secret',
  'cert-manager-email',
  vault_url=vault_url
  ) }}"

dex_client_id:  "{{ lookup(
  'azure.azcollection.azure_keyvault_secret',
  'dex-client-id',
  vault_url=vault_url
  ) }}"
dex_client_secret:  "{{ lookup(
  'azure.azcollection.azure_keyvault_secret',
  'dex-client-secret',
  vault_url=vault_url
  ) }}"
dex_github_client_id: "{{ lookup(
  'azure.azcollection.azure_keyvault_secret',
  'dex-github-client-id',
  vault_url=vault_url
  ) }}"
dex_github_client_secret: "{{ lookup(
  'azure.azcollection.azure_keyvault_secret',
  'dex-github-client-secret',
  vault_url=vault_url
  ) }}"

kubeapps_oauth_proxy_cookie_secret: "{{ lookup(
  'azure.azcollection.azure_keyvault_secret',
  'kubeapps-oauth-proxy-cookie-secret',
  vault_url=vault_url
  ) }}"

```

> **Note** Nous n'aurons pas besoin d'utiliser les variables de connection du plugin. Comme nous serons sur une machine azure, celle-ci aura les habilitations requises pour accèder directement aux secrets.

Puis on définit un fichier `hosts` pointant directement sur localhost. 

[playbook/inventories/azure/hosts](playbook/inventories/azure/hosts)
```ini
127.0.0.1
```

Nous allons rester sur localhost avec un provision sur la machine même dans les prochaines étapes packer et terraform.

## Packer Créer une image virtuelle

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

> **Note**: recommandation : extension `szTheory.vscode-packer-powertools` (elle contient un bon fortmatteur de fichier HCL),`hashicorp.hcl`.

Vérification packer 1.8+ bien installé dans votre ligne de commande
```sh
packer --version

```

Puis nous avons besoin de la ligne commande de azure pour créer notre service principal. Pour cela il faut installer le [CLI azure](https://docs.microsoft.com/fr-fr/cli/azure/install-azure-cli)

Connectez vous avec **`az login`** à votre compte azure.

> **Note** Vous devez avoir un abonnement azure avec du crédit disponible. (exemple: essai de 200$ offert)

##### Puis créer le `groupe de ressources` dans lequel on va créer tout nos composants azure :

```bash
az group create --name kubeapps-group --location westeurope
```

### B. Initialisez un projet packer

```sh
mkdir infra/
cd infra
touch vars.json
touch ubuntu.pkr.hcl
```

Ajouter ce gitignore recommandé dans le dossier `infra/`

```bash
curl -L https://github.com/github/gitignore/raw/main/Packer.gitignore | tee .gitignore
```

> [infra/ubuntu.pkr.hcl](infra/ubuntu.pkr.hcl)

```hcl
variable "resource_group_name" {
  type    = string
  default = "kubeapps-group"
}

variable "image_sku" {
  type    = string
  default = "20_04-daily-lts-gen2"
}

variable "vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}

```

> [infra/ubuntu.pkr.hcl](infra/ubuntu.pkr.hcl#L56)

```hcl
source "azure-arm" "vm" {
  use_azure_cli_auth = true

  managed_image_name                = "kubeapps-az-arm"
  managed_image_resource_group_name = var.resource_group_name
  build_resource_group_name         = var.resource_group_name
  os_type                           = "Linux"
  image_publisher                   = "Canonical"
  image_offer                       = "0001-com-ubuntu-server-focal-daily"
  image_sku                         = var.image_sku

  vm_size      = var.vm_size
  communicator = "ssh"
}
```

Lors du processus de build packer, **nous ne sommes pas accessible sur internet** ce qui rend impossible l'installation de certificats letsencrypt avec cert-manager. Nous allons donc désactiver l'installation de kubeapps durant le build pour plutôt la lancer avec un script de démarrage qui relancera simplement le playbook avec le tag `kubeapps`.

Ensuite, on utilise le provisionner ansible qui va installer notre playbook sur la machine azure :

[infra/ubuntu.pkr.hcl](infra/ubuntu.pkr.hcl#L74)

```hcl

build {

  sources = ["sources.azure-arm.vm"]

  provisioner "file" {
    source      = "../playbook/requirements.txt"
    destination = "requirements.txt"
  }

  provisioner "shell" {
    inline = [
      "curl https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py",
      "sudo python3 /tmp/get-pip.py",
      "sudo pip3 install --ignore-installed ansible==6.5.0 pyyaml openshift kubernetes",
      "sudo mkdir /playbook && sudo chown -R packer:packer /playbook",
    ]
  }

  provisioner "ansible-local" {
    command       = "sudo ansible-playbook"
    playbook_file = "../playbook/site.yaml"
    playbook_dir  = "../playbook/"
    extra_arguments = ["--skip-tags kubeapps"]
    galaxy_file             = "../playbook/requirements.yaml"
    galaxy_command          = "sudo ansible-galaxy"
    galaxy_roles_path       = "/usr/share/ansible/roles"
    galaxy_collections_path = "/usr/share/ansible/collections"
    staging_directory       = "/playbook/"
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"
    ]
    inline_shebang = "/bin/sh -x"
  }
}

```

> **Note**: le provisionner shell est nécessaire pour déprovisionner l'agent azure qui est installé par défaut sur les images générées par azure.

Toujours dans `infra/`, on lance le traitement entier avec packer :

```bash
packer build ubuntu.pkr.hcl
```

Vous pourrez voir le résultat de la création de l'image dans le portail azure dans votre groupe de ressource `kubeapps-group`.

## Obtenir un nom de domaine gratuit (étudiants)

> **Warning** Cette étape intermédiaire est indispensable pour la suite du tutoriel.

Allez sur [https://education.github.com/](https://education.github.com/) et valider votre compte étudiant. Normalement votre email étudiant devrait être reconnu très facilement.

Après nous allons utiliser des noms de domaines offert par **name.com** :

- Allez à [https://education.github.com/pack/offers#namecom](https://education.github.com/pack/offers#namecom)

- Veillez bien à ne pas être connecté à `name.com` dans le cas où vous seriez déjà inscrit

- Cliquer Get access by connecting your GitHub account on Name.com et accepter les droits demandés par l'application sur github.

- Connectez vous à github en cliquant sur le bouton qui devrait être au milieu de la page.

- Dans **domains** chercher un domaine en `.live` de votre choix (par exemple `paas-tutorial-lesgi.live`)

- Ensuite ajoutez le au panier et aller à checkout en cliquant à nouveau. [`Panier > Checkout`](https://www.name.com/account/checkout) Le code promo est censé être appliqué automatiquement grâce à la connection à Github.

- Ensuite poursuivez en vous inscrivant à name.com et validez votre email puis valider l'achat qui ne doit rien vous couter si la manipulation à a été faite correctement.

## Lancement de la vm avec Terraform

Introduction sur terraform [doc](https://www.terraform.io/intro/index.html)

Cet Outil de codage déclaratif ou d'**IaC** (infrastructure as code), Terraform permet d'utiliser un langage de configuration appelé HCL (HashiCorp Configuration Language) à la place de l'API d'un fournisseur de cloud. On peu ainsi décrire l'infrastructure cloud de manière déclarative et automatisée avec une seule simple ligne de commande. Terraform génère ensuite un plan permettant d'atteindre un état final de l'infrastructure et exécute le plan pour mettre à disposition l'infrastructure.

Terraform permet de faire des infrastructures immuables que l'on peut versionner, partager, installer et détruire à la demande.
Il ne se limite pas seulement à ça mais à toutes les automatisation mise à disposition par des produits souvent autour du cloud.

https://learn.microsoft.com/en-us/azure/virtual-machines/custom-data

**Toujours dans le dossier `infra/` :**

Pour commencer ajouter ce gitignore dans le dossier `infra/` pour éviter le déchet :

```bash
curl -L https://github.com/github/gitignore/raw/main/Terraform.gitignore | tee -a .gitignore
```

> `-a` comme append, on ajoute à la fin du fichier et on n'écrase pas l'existant.

### Nomenclature de terraform :

Un block `data` dans un fichier de configuration terraform `tf` sert à importer des données existante sur la plateforme.

Un block `resource` dans un fichier de configuration terraform `tf` sert à créer des ressources sur la plateforme.

Un block `locals` dans un fichier de configuration terraform `tf` sert à définir des variables locales.

Un block `provider` dans un fichier de configuration terraform `tf` sert à définir le provider de cloud.

Il existe aussi `variable` et `output` qui servent à définir des variables d'entrée et de sortie.

### Organisation des fichiers du dossier `infra/`


1. Les providers

Premièrement, nous allons créer un fichier `terraform.tf` qui va se charger de définir les ressources terraform de notre infrastructure. On va passer par plusieurs plateforme différentes :

- **`github`** pour définir les équipes accèdant à kubeapps en controlant une organisation github.

- **`azurerm`** pour controler l'intégralité des ressources azure que l'on peut consulter dans le portail.

- **`namedotcom`** pour contrôler les zones du domaine que l'on a obtenu précédemment.

```tf
terraform {

  required_version = ">=0.12"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.37"
    }
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
    namedotcom = {
      source  = "lexfrei/namedotcom"
      version = "1.2.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.9.1"
    }
  }
}

provider "github" {
  token = var.github_token
  owner = var.github_organization
}

provider "namedotcom" {
  token    = var.namedotcom_token
  username = var.namedotcom_username
}

provider "azurerm" {
  tenant_id = var.tenant_id
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

```

> Comme nous nous sommes connecté avec `az login` auparavent, aucun identifiants n'est requis pour faire fonctionner le provider azurerm.
> **Warning** Vérifiez bien toutefois que votre tenant par défaut soit bien celui de votre abonnement avec du crédit. Pour vérifier :

```bash
az account list -o table --all --query "[].{TenantID: tenantId, Subscription: name, Default: isDefault}"`
```

Si ce n'est pas le bon vous pouvez le changer avec `az login --tenant $ID` ou utilisez une variable terraform `tenant_id` à ajouter au provider `azurerm`

Nous voici prêt pour créer les datasources et les ressources de nos cloud sans emcombres.

---

2. Les datasources

Nous allons premièrement définir un fichier `data.tf` accessible tout au long du processus de création des ressources terraform.

[infra/data.tf](infra/data.tf)

```tf
data "azurerm_resource_group" "paas" {
  name = "kubeapps-group"
}

data "azurerm_image" "search" {
  name                = "kubeapps-az-arm"
  resource_group_name = data.azurerm_resource_group.paas.name
}

data "azurerm_client_config" "current" {}
data "azurerm_subscription" "primary" {}

```

- `azurerm_resource_group` nous permet de récupérer le groupe de ressource créé précédemment avec la ligne de commande azure.

- `azurerm_client_config` permet de récupérer les information de connexion de l'utilisateur courant que l'on a lancer avec `az login`.

- `azurerm_subscription` récupère l'identifiant de votre abonnement en cour.

---

3. Les variables d'entrée

Pour éviter de commit des secrets sur un git distant et centralisé les configuration importantes, nous allons recourir à des variables terraform.

> `sensitive` permet de cacher la valeur de la variable dans le terminal lors de l'execution de terraform.

[infra/variables.tf](infra/variables.tf)

```tf

variable "github_team" {
  type = string
}

variable "github_token" {
  type = string
  sensitive = true
}

variable "cert_manager_letsencrypt_env" {
  type = string
  default = "prod"
}

variable "domain" {
  type = string
}

variable "namedotcom_token" {
  type = string
  sensitive = true
}

variable "namedotcom_username" {
  type = string
  sensitive = true
}

variable "secrets" {
  type = map(string)
  description = "Define Azure Key Vault secrets"
  default = {}
}

```

Pour remplir ces variables dans un fichier nommé `votre-env.tfvars` (ex prod.tfvars) il nous reste à obtenir certains token d'accès aux api (github et namedotcom).

**L'application github oauth pour la production** :

Il n'y a malheureusement pas d'automatisation possible avec terraform, il faut donc [créer une nouvelle application github](https://github.com/organizations/<my-org>/settings/applications/new) avec les paramètres suivants :

- Application name : `kubeapps-prod`
- Homepage URL : https://kubeapps.<ton-nom-de-domaine>.example
- Authorization callback URL : https://dex.<ton-nom-de-domaine>.example/callback

Dans `exemple.tfvars`, on assignera **Client Id** à `dex_github_client_id` puis générez un nouveau **Client secret** que l'on assignera à `dex_github_client_secret`.

**Identifiants api à name.com** :

Allez [https://www.name.com/account/settings/api](https://www.name.com/account/settings/api) et crééer un token avec le nom de votre choix.

L'objectif sera de faire pointé notre nom de domaine vers les serveurs de nom de azure (enregistrement NS) grâce à un module terraform qui utilisera l'api de name.com.

Enfin, voici un exemple du fichier final à réutiliser et remplir avec les vrais valeurs :

[infra/example.tfvars.dist](infra/exemple.tfvars.dist)

```tf
tenant_id="00000000-0000-0000-0000-000000000000"
github_organization = "github-team"
github_team         = "ops-team"
domain              = "paas-esgi-tutorial.live"
namedotcom_username = "username"
namedotcom_token = "aaaaaaaaaaaaaaaaaaaaaaaaaaaa"
github_token = "ghp_aaaaaaaaaaaaaaaaaaxxxxxxxxxxxx"

secrets = {
  dex_github_client_id = "dex-github-oauth2-app-client-id"
  dex_github_client_secret = "dex-github-oauth2-app-client-secret"
  cert_manager_email = "paas-esgi-tutorial.live4@example.com"
}

```

Ces variables seront utilisées dans le fichier `main.tf` pour créer les ressources.

4. Le fichier principal `main.tf`

Ici nous allons définir les ressources de nos plusieurs plateform afin de faire fonctionner un PaaS kubeapps complet et accessible depuis internet.

La première partie va concerné github et les équipes ayant accès au PaaS.

Ensuire dans une seconde dédié aux ressources Azure, nous allons définir :

- La création de la vm
- Création de l'environnement réseau et de sa sécurisation (ports ouverts)
- Attribution d'une ip publique pour l'interface réseau de la machine
- Créer un stockage de secrets sécurisé pour l'application kubeapps (feature `key_vault`)
- La gestion des zones dns

Enfin au milieu de tout ça lors de la création des zones dns dans azure nous ajouterons un enregistrement NS qui pointe vers les serveurs de nom de name.com grâce au provider `namedotcom`.


#### Création des équipes github

#### Création du key vault et des secrets

- [terraform keyvault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret)

- [keyvault azure](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/tutorial-windows-vm-access-nonaad#grant-access)

Dans le datasource `data.tf` nous allons récupérer les membres de l'organisation github et les membres admin de notre organisation.
Nous utilisons des boucles pour remplir les dictionnaires `github_membership.all` et `github_membership.all_admin`

[infra/data.tf](infra/data.tf#L13)

```tf
data "github_organization" "org" {
  name = var.github_organization
}

data "github_membership" "all" {
  for_each = toset(data.github_organization.org.members)
  username = each.value
}

data "github_membership" "all_admin" {
  for_each = {
    for _, member in data.github_membership.all:
    _ => member if member.role == "admin"
  }
  username = each.value.username
}

```

Puis nous allons créer l'équipe github puis assigner comme membre tous les administrateurs de l'organisation à celle-ci.

[infra/main.tf](infra/main.tf)

```tf
############
# Accounts
############
resource "github_team" "opsteam" {
  name        = var.github_team
  description = "This is the production team"
  privacy     = "closed"
}

resource "github_team_membership" "opsteam_members" {
  for_each = data.github_membership.all_admin
  team_id  = github_team.opsteam.id
  username = each.value.username
  role     = "member"
}
```

#### Création du key vault et des secrets

Pour des raisons essentitelles de sécurité nous mettons à disposition de la machine virtuelle un stockage de secrets sécurisé grâce à la ressource terraform `azurerm_key_vault`

```tf
############
# Key vault
############
resource "random_id" "kvname" {
  byte_length = 5
  prefix      = "keyvault"
}

resource "azurerm_key_vault" "paas" {
  name                       = random_id.kvname.hex
  location                   = data.azurerm_resource_group.paas.location
  resource_group_name        = data.azurerm_resource_group.paas.name
  soft_delete_retention_days = 7

  tenant_id = data.azurerm_client_config.current.tenant_id

  purge_protection_enabled        = false
  enabled_for_disk_encryption     = true
  enabled_for_deployment          = true

  sku_name = "standard"

  lifecycle {
    create_before_destroy = true
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "Set", "Backup", "Delete", "List", "Purge", "Recover", "Restore",
    ]
  }
}

```

On nomme donc ce keyvault avec une ressource de nom aléatoire `random_id` puis on lui associe les informations habituelles du groupe de ressource.

`soft_delete_retention_days` permet de définir le nombre de jours pendant lesquels des secrets supprimés pourront être réstaurés.

`tenant_id` permet de définir le propriétaire du keyvault.

Ensuite nous utilisons des propriétés de base pour rendre les secrets accessibes pour différents type d'utilisation, définir le type de keyvault et son cycle de vie.

Le block `lifecycle` est une fonctionnalité de terraform qui change la façon dont est recréer la ressource avant une modification.

Enfin le plus important est le block `access_policy` qui permet de définir les permissions de l'utilisateur qui va accéder au keyvault. Ici on les définit pour le `tenant id` et le `principal id` contenus dans le client azure courant (utilisateur connecté avec azure cli).

##### Utilisons maintenant le keyvault pour stocker nos secrets

Pour stocker nos secrets nous utilisons la ressource `azurerm_key_vault_secret` qui permet de stocker des secrets dans le keyvault créé précédemment. Nous allons utiliser les secrets créer dans `variables.tf` ainsi que des mots de passes générés aléatoirement pour certaines configurations de `dex` et `kubeapps`.

```tf
# Kubeapps OAuth Proxy
resource "random_password" "kubeapps_oauth_proxy_cookie_secret" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Dex oidc client
resource "random_password" "dex_client_id" {
  length  = 16
  special = false
}

resource "random_password" "dex_client_secret" {
  length  = 24
  special = false
}

# Vm password
resource "random_password" "vm_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

locals {
  final_secrets = merge(
    var.secrets,
    {
      vm_password                        = random_password.vm_password.result
      dex_client_id                      = random_password.dex_client_id.result
      dex_client_secret                  = random_password.dex_client_secret.result
      kubeapps_oauth_proxy_cookie_secret = random_password.kubeapps_oauth_proxy_cookie_secret.result
    }
  )
}

resource "azurerm_key_vault_secret" "paas_all_secrets" {
  for_each     = local.final_secrets
  name         = replace(each.key, "_", "-")
  value        = each.value
  key_vault_id = azurerm_key_vault.paas.id
}

```
> On fusionne les secrets définis dans `variables.tf` avec les secrets générés aléatoirement pour un appel à la ressource encore plus simple.

> Nous utilisons donc une boucle `for_each` pour éviter la répétition des ressources secrets.

#### Création de l'environnement réseau

Ces directives sont essentiellement tirées de la documentation officielle de terraform pour azure. Il faut savoir que l'usage d'azure pour créer une machine nous indique l'utilisation d'un réseau virtuel (DHCP) et d'un sous-réseau afin de la rendre accessible avec une addresse IP privée.

`azurerm_virtual_network` et `azurerm_subnet` nous permettent de faire ça facilement dans notre groupe de ressources.


[infra/main.tf](infra/main.tf#L97)
```
############
# Vm Network
############
resource "azurerm_virtual_network" "paas" {
  name                = "paas-vn"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.paas.location
  resource_group_name = data.azurerm_resource_group.paas.name
}

resource "azurerm_subnet" "paas" {
  name                 = "paas-sub"
  resource_group_name  = data.azurerm_resource_group.paas.name
  virtual_network_name = azurerm_virtual_network.paas.name
  address_prefixes     = ["10.0.2.0/24"]
}
```

[infra/main.tf](infra/main.tf)

```tf
resource "azurerm_network_security_group" "paas" {
  name                = "paas-security-gp"
  location            = data.azurerm_resource_group.paas.location
  resource_group_name = data.azurerm_resource_group.paas.name

  security_rule {
    name                       = "HTTP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "paas_security_group" {
  subnet_id                 = azurerm_subnet.paas.id
  network_security_group_id = azurerm_network_security_group.paas.id
}

```

```tf
resource "azurerm_public_ip" "paas" {
  name                = "paas-ip"
  resource_group_name = data.azurerm_resource_group.paas.name
  location            = data.azurerm_resource_group.paas.location
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "paas" {
  name                = "paas-nic"
  location            = data.azurerm_resource_group.paas.location
  resource_group_name = data.azurerm_resource_group.paas.name

  enable_accelerated_networking = true

  ip_configuration {
    name                          = "paasconfiguration1"
    subnet_id                     = azurerm_subnet.paas.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.paas.id
  }
}
```

#### Configuration de la zone dns

Azure a de très bon outils pour la gestion des zones dns. On va donc utiliser le provider `azurerm` pour créer une zone dns et récupérer les serveurs dns associés.

```hcl
############
# Dns
############
resource "azurerm_dns_zone" "paas" {
  name                = var.domain
  resource_group_name = data.azurerm_resource_group.paas.name
}
```

Voici le retour de la ressource créer qui donne tous les serveurs dns requis pour faire fonctionner la zone dns.

```json
[
    "ns1-03.azure-dns.com.",
    "ns2-03.azure-dns.net.",
    "ns3-03.azure-dns.org.",
    "ns4-03.azure-dns.info."
]
```

Ensuite on arrive facilement à récupérer les serveurs dns puis les reformater (enlever les `.` à la fin) avant de les injecter dans le fournisseur de noms name.com

```
resource "namedotcom_domain_nameservers" "namedotcom_paas_ns" {
  domain_name = var.domain
  nameservers = [
    # Delete ending dot which isn't valid for namedotcom api
    for item in azurerm_dns_zone.paas.name_servers : trimsuffix(item, ".")
  ]
}
```

Enfin on met en place le **wildcard** pour la zone dns afin que tous les sous domaines pointent vers l'ip publique de la vm. Ainsi n'importe quel sous domaine de `paas-exemple-tutorial.live` pointera vers l'ingress de k3s.

```hcl
resource "azurerm_dns_a_record" "paas" {
  name                = "*"
  zone_name           = azurerm_dns_zone.paas.name
  resource_group_name = data.azurerm_resource_group.paas.name
  ttl                 = 3600
  target_resource_id  = azurerm_public_ip.paas.id
}

```

C'est comme cela que l'on arrive à avoir un nom de domaine comme `kubeapps.paas-exemple-tutorial.live` qui pointe vers l'ingress de k3s.

#### Création de l'identité de la vm

[infra/main.tf](infra/main.tf#L50)

```hcl
############
# Vm creation
############
resource "azurerm_user_assigned_identity" "paas_vm" {
  location            = data.azurerm_resource_group.paas.location
  name                = "paas_vm_identity"
  resource_group_name = data.azurerm_resource_group.paas.name
}

resource "azurerm_key_vault_access_policy" "paas_vm" {
  key_vault_id = azurerm_key_vault.paas.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.paas_vm.principal_id

  key_permissions = ["Get",]

  secret_permissions = [
    "Get", "List", "Recover", "Restore",
  ]

  storage_permissions = [ "Get" ]
}
```

- La ressource `azurerm_user_assigned_identity` permet de créer une identité et d'ensuite accèder à ses informations de connection (tenant, service principal..)

- `azurerm_key_vault_access_policy` défini les permissions de l'identité sur le keyvault. Ici on lui donne les droits de lecture sur les secrets. `key_vault_id` est obligatoire pour lié la politique au keyvault.

#### Création de la vm

[infra/main.tf](infra/main.tf#L50)

```hcl
resource "azurerm_virtual_machine" "paas" {
  name                  = "paasvm"
  location              = data.azurerm_resource_group.paas.location
  resource_group_name   = data.azurerm_resource_group.paas.name
  network_interface_ids = [azurerm_network_interface.paas.id]
  vm_size               = "Standard_DS2_v2"

  storage_image_reference {
    id = data.azurerm_image.search.id
  }

  delete_os_disk_on_termination = false

  storage_os_disk {
    name              = "paasdisk1"
    create_option     = "FromImage"
    caching           = "ReadWrite"
    managed_disk_type = "StandardSSD_LRS"
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.paas_vm.id
    ]
  }

  os_profile {
    computer_name  = "paasvm"
    admin_username = "kubeapps"
    admin_password = azurerm_key_vault_secret.paas_all_secrets["vm_password"].value

    # ... For later
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}
```

- Tout en haut nous avons associé une interface réseau à la vm, définit le groupe, la zone et l'abonnement CPU azure [explication des séries](https://azure.microsoft.com/fr-fr/pricing/details/virtual-machines/series/). Ici nous avons choisi une machine classique pour des besoins de production.

- `storage_image_reference` permet d'indiquer l'image à utiliser pour la vm. Ici on utilise notre image que l'on récupère avec un datasource `azurerm_image`.

[infra/data.tf](infra/data.tf#L5)

```hcl
data "azurerm_image" "search" {
  name                = "kubeapps-az-arm"
  resource_group_name = data.azurerm_resource_group.paas.name
}
```

- `storage_os_disk` défini le type de disque dur, son nom et sa source si on utilise une image existante comme c'est le cas ici.

> **Warning** `delete_os_disk_on_termination = false` devrait être mis à true en debug pour éviter de bloquer le `terraform destroy`

- `identity` associe à l'identité azure créer précédemment. Cela permettra à la vm de récupérer les secrets du keyvault.

### Provision final de la machine virtuelle

Nous allons donc recourrir au [module cloud init ansible](https://cloudinit.readthedocs.io/en/latest/topics/modules.html#ansible) déclenché automatiquement au provision azure de la vm grâce à quelques configurations.

Ce fichier cloud-init.yml est un [template terraform](https://developer.hashicorp.com/terraform/language/functions/templatefile) qui va être utilisé pour générer un fichier cloud-init.yml final. On peut y injecter des variables au travers de la propriété `custom_data` du sous module `os_profile` de `azurerm_linux_virtual_machine` et de la fonction `templatefile` de terraform.

> **Note** En interne ce fichier sera converti en base64 et injecté dans la vm

On ajoute donc un objet avec toutes les variables requises au bon fonctionnement du playbook.

On rappele que `vault_url` est une variable qui contient l'url du keyvault azure et que l'on va l'utiliser avec ansible et le plugin lookup [`azure_keyvault_secret`](https://docs.ansible.com/ansible/devel/collections/azure/azcollection/azure_keyvault_secret_lookup.html) pour récupérer les secrets.

> **Note** L'inventaire [playbook/inventories](playbook/inventories) a été créer dans les étapes précédente et se trouve dans notre image créer avec `packer`

[infra/main.tf l.226](infra/main.tf#L226)
```tf
    custom_data = templatefile(
      "${path.module}/cloud-init.yaml",
      {
        kubeapps_hostname      = "kubeapps.${azurerm_dns_zone.paas.name}"
        dex_hostname           = "dex.${azurerm_dns_zone.paas.name}"
        vault_url              = azurerm_key_vault.paas.vault_uri
        dex_github_client_org  = data.github_organization.org.orgname
        dex_github_client_team = github_team.opsteam.name
        cert_manager_letsencrypt_env = var.cert_manager_letsencrypt_env
      }
    )
```


- `datasource` configure le module pour qu'il récupère les informations de la vm azure (notamment les secrets du keyvault)

- `ansible` permet de construire une commande ansible qui va être exécutée au démarrage de la vm. Il s'agit d'un template terraform

[infra/cloud-init.yml](infra/cloud-init.yml)

```yaml
#cloud-config

datasource:
  Azure:
    apply_network_config: true
    data_dir: /var/lib/waagent
    disk_aliases:
      ephemeral0: /dev/disk/cloud/azure_resource

runcmd:
  - [sleep, 20]

ansible:
  install_method: pip
  package_name: ansible
  setup_controller:
    run_ansible:
      - playbook_dir: /playbook
        inventory: /playbook/inventories/azure/hosts
        playbook_name: site.yaml
        extra_vars: "vault_url=${vault_url}
           dex_github_client_org=${dex_github_client_org}
           dex_github_client_team=${dex_github_client_team}
           cert_manager_letsencrypt_env=${cert_manager_letsencrypt_env}
           kubeapps_hostname=${kubeapps_hostname}
           dex_hostname=${dex_hostname} -o 'IdentitiesOnly=yes'"
        connection: local
  
```

#### Application de l'infrastructure finale

Puis appliquer l'infrastructure sans message de confirmation :

```bash
terraform apply -auto-approve -var-file prod.tfvars
```

> `-var-file` est indispensable pour charger les variables de l'environnement, sans ça vous êtes obligé de rentrer les variables à la main.


#### FAQ

J'ai essayé plusieurs fois le provision de la vm avec des configurations différentes me forçant ainsi à apply / destroy la stack plusieurs fois. Cependant, maintenant je n'arrive plus à accèder à l'url avec une **erreur dns** ?

Il s'agit probablement du cache dns qui vous renvoi l'entrée ip d'une ancienne vm car le time to live n'a pas encore expiré. Pour cela dans chrome nous devons nettoyer ce cache pour faire comme si nous n'étions jamais aller sur le site.
Dans [chrome://net-internals/#dns]([chrome://net-internals/#dns]) faites un clear host cache et réessayez.

> Pour faire des tests en cas réel, il est préférable d'utiliser des entrées `dex_hostname` et `kubeapps_hostname` différentes que vous n'utlisez pas pour un environement (staging ou production).
