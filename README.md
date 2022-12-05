# Paas Tutorial

## Requis

- Un PC / Mac peut importe l'OS
- Des bases d'administration linux
- Un minimum de culture sur les systèmes d'**Info**rmation
- Connaissance des concepts d'environnements isolés linux ou **containers**
- Un compte [github](http://github.com/)

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
pip install ansible molecule[docker] dnspython
```

> `dnspython` servira à faire fonctionner un module d'ansible. On ajoutera des détails plus tard.

> ****Warning**** Les shell un peu exotique comme fish pour l'utilisation de molecule ne sont pas recommandés

Vérifier que tous fonctionne avec `ansible --version`.

Vous devriez avoir `ansible [core 2.13.4]` dans le retour

### **Bonus** pour faire fonctionner l'extension VsCode ansible

> WARNING: Utilisateur du WSL **Pour utiliser vscode, faites le impérativement via la ligne de commande linux WSL dans votre projet `~/paas-tutorial`** : `code .`

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
echo "ansible==6.4.0\nmolecule==4.0.1\ndnspython" > requirements.txt
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

> **Info** pour l'instant il y a un bug avec galaxy nous empêchant de récupérer la bonne version de k3s. On peut forcer l'utilisation direct de git pour récupérer la version 3.3.0

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

Les **collections** vont servir à ajouter des fonctionnalités à ansible et ses directives de tâches. Ici on ajoute les fonctionnalités fondamentales ainsi que celles pour manipuler notre cluster kubernetes (abstraction de la commande `kubectl`).

Les **roles** correspondent à des suites de tâches qui vont installer et configurer un outil sur une machine. Ici on utilisera un [role k3s](https://github.com/PyratLabs/ansible-role-k3s) qui s'occupe de configurer en fonction de nos paramètre le cluster k3s.

> **INFO** K3s n'utilise pas `docker` mais `containerd` pour utiliser les fonctionnalités de container linux.

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

Nous allons ensuite mettre à jour les métadonnées ansible galaxy avec notamment la dépendance kubernetes (rôle k3s)

> Ligne 50 de [playbook/roles/kubeapps/meta/main.yml](playbook/roles/kubeapps/meta/main.yml)
```yaml
dependencies:
    - src: xanmanning.k3s
      version: v3.3.0
```

Ensuite vous devez obligatoirement définir ces **Info**rmations sur les metas du rôles:

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

> **Info** dans notre cas nous ferons appel à un seul noeud master

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

> **Info** Un **reverse proxy** est à l'inverse d'un proxy chargé d'effectuer une action à partir d'une requète réseau externe. On l'utilise majoritairement avec un serveur DNS qui fait pointé des noms de domaines et sous domaines vers l'adresse Ip du serveur sur lequel un reverse proxy est installé.
> Par exemple il va servir à rediriger le traffic de la requète `kubeapps.svc.test` vers une addresse et port réseau attribué par kubernetes à un pod.

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
    published_ports:
      - 6443:6443
      - 80:80
      - 443:443
      - 32444:32444 # pebble management
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

> **Warning** : le `name` de la platform va nous servir d'addresse réseau par laquelle ansible sur l'hôte va pourvoir accèder en ssh. Il est indispensable de le renseigner car le role k3s en a besoin pour bien créer les noeud du cluster kubernetes. (même si on en utilise un seul)

L'image du container `geerlingguy/docker-${MOLECULE_DISTRO:-ubuntu2004}` va nous permettre d'utiliser un linux préconfiguré qui s'initialise avec le démon `systemd`. Celui ci est une fonctionnalité assez neuve du coeur et recommandée pour la gestion des services en arrière plan (daemons) soit ici k3s

On note que l'on publie le port `80` et `443` à des fins de debug pour exposer Ingress.

> `32444` le port pebble servira plus tard pour accèder à notre serveur ACME

> ****Warning** vérifiez bien que aucun autre processus su votre machine n'utilise déjà le port 80 et 443**

Les **volumes** que l'on utilise servent à rendre disponible des fonctionnalités du coeur linux désactivées par défaut sur des containers docker comme `systemd` et les [espaces de nom](https://fr.wikipedia.org/wiki/Espace_de_noms) / [`cgroup` version 2](https://kubernetes.io/docs/concepts/architecture/cgroups/). 
Même chose pour les répertoire temporaire `tmpfs` qui assurent le bon fonctionnement de ces outils. 
Enfin `priviledgied: true` nous donne les droits administrateur complets sur le système du container.

Le playbook `verifier` va ensuite nous permettre de tester la bonne execution du rôle et de ses dépendances.

>Notes :
> - `hosts: all` permet de jouer le playbook sur tous les hôtes
> - `role: {{etc...}}` résoud le chemin de fichier vers le répertoire du rôle
> - Les pré-tâches servent à installer des packages linux et python manquant à notre container utiles pour l'environnement local et les tests.

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
    - name: Ensure test dependencies are installed (Debian).
      package: 
        name: iptables
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

Ensuite grâce au module ansible [k8s info](https://docs.ansible.com/ansible/latest/collections/kubernetes/core/k8s_info_module.html) nous allons vérifier que k3s est bien prêt avec deux vérifications :

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

> On note qu'il est important de préciser à `k8s_info` la localisation kubeconfig qui se trouve à un endroit un peu exotique sur k3s. Cette config comporte des informations utilisateur et des certificats permettant de se connecter sur le cluster.

Lancer votre premier test avec `molecule test` et voilà vous avez un playbook offrant un cluster kubernetes prêt à l'emploi tout en suivant rigoureusement le concept du test driven development pour plus de fiabilité.

> **Info** : Vous pouvez aussi lancer `molecule test --destroy never` pour ensuite garder le container et debugger l'état du système après le provision ansible avec `molecule login` (qui équivaut à `docker exec -it node-0 bash`)

> **Info** : En cas d'erreur `export ANSIBLE_STDOUT_CALLBACK=yaml` avant de lancer `molecule test` pour avoir un meilleur rendu de la possible erreur.

Eensuite dans la suite du fichier on procède à une vérification des pods de la suite k3s. 

> Vous pourrez relancer seulement la suite de vérification avec `molecule verify` si votre container n'a pas été détruit (`--destroy false`)

Nous savons ici que k3s est lancé. En sachant que ce rôle est externe nous n'avons pas besoin de faire plus de tests sur ces composants centraux disposés dans le namespace `kube-system`.

Nous allons par contre de manière originale se lancer dans une approche Test driven developement / test first en écrivant directement les scénarios pour vérifier les resources de kubeapps. 

> [playbook/roles/kubeapps/molecule/default/verify.yml](playbook/roles/kubeapps/molecule/default/verify.yml#L18)
```yaml
- name: Get Kubeapps service infos
  kubernetes.core.k8s_info:
    api_version: v1
    kind: Service
    name: kubeapps
    kubeconfig: /etc/rancher/k3s/k3s.yaml
    wait: yes
    namespace: "kubeapps"
  register: kubeapps_infos

- name: Assertions on service kubeapps 
  assert:
    that:
      - kubeapps_infos.resources | length > 0
      - kubeapps_infos.resources[0].spec.type == "ClusterIP"

```

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

### G. Ajout de la solution de PaaS Kubeapps dans notre rôle

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

- `templates/kubeapps-chart-crd.yml.j2` qui est un template `jinja` représentant plusieurs manifests kubernetes.

- `tasks/manifests.yaml` : celui-ci va s'occuper de placer les manifests kubernetes dans le répertoire `/var/lib/rancher/k3s/server/manifests` pour que k3s déploie automatiquement les resources décrites dans ceux-ci.

> Source pour plus d'informations [doc k3s](https://docs.k3s.io/helm#customizing-packaged-components-with-helmchartconfig)

Commencons par construire notre manifest. Pour cela nous avons besoin de définir plusieurs variables pour rendre configurable l'utilisation de notre rôle :

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

> **Info** sur le templating jinja dans la moustache `{{}}` rajouter un `-` signifie que l'on ignore le format du côté ou l'on utilise. Par exemple un retour à la ligne (colonne 0) sera ignorer pour `-}}`.

> WARN le filtre `to_nice_yaml` convertis nos objet ansible en yaml et l'indispensable `indent(width=6)`.

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
      {{ kubeapps_ingress | to_nice_yaml | indent(width=6) -}}

```

> **Info** On configure le ingress directement dans la définition helm tout en précisant bien que l'on utilise traefik en sachant que par défaut il est souvent utilisé `nginx` comme cntroller ingress

Nous allons lancer la commande de templating grâce au module `template` de la collection **builtin** (fonctionnalités inclus par défaut) de ansible.

Celle ci va faire le remplacement des variable utilisées dans les moustaches `{{}}` et placer le fichier au bon endroit dans notre machine invité. Ici il se trouvera dans notre container `node-0` dans le répertoire `/var/lib/rancher/k3s/server/manifests/kubeapps-chart-crd.yml`

```yaml
---
- name: deploy kubeapps chart with k3s
  ansible.builtin.template:
    src: "{{ kubeapps_chart_crd }}.j2"
    dest: "/var/lib/rancher/k3s/server/manifests/{{ kubeapps_chart_crd }}"
    owner: "{{ kubeapps_user }}"
    group: "{{ kubeapps_user }}"
    mode: '0644'

```

Enfin on rempli le fichier d'entrée comme ceci :

[playbook/roles/kubeapps/tasks/main.yml](playbook/roles/kubeapps/tasks/main.yml)

```yaml
---
- import_tasks: manifests.yml
  tags: [kubeapps]
```

Ici c'est assez simple on inclus les tâches du fichier `manifests.yml` et on tag cette inclusions avec le label `kubeapps`. Ainsi avec ansible on peut choisir d'éxécuté seulement les tâches avec ce tag et donc seulement ce qu'on trouve dans notre rôle kubeapps.


Enfin on ajoute un test pour vérifier que les pods de kubeapps sont bien prêt :

- On regarde d'abord si la tâche `helm` a bien pu se finir

> [playbook/roles/kubeapps/molecule/default/verify.yml](playbook/roles/kubeapps/molecule/default/verify.yml)
```yaml
    - name: Assert kube-system helm task for kubeapps is ok
      ansible.builtin.assert:
        that: "{{ (pods | 
          select('search', 'helm-install-kubeapps') | 
          select('search', 'Completed') | list
          ) | length }}"

```
- On vérifie que les pods en cour d'éxécution sont bien au nombre de 10 (on utilise la même méthode que pour vérifier que k3s est bien prêt)

> [playbook/roles/kubeapps/molecule/default/verify.yml](playbook/roles/kubeapps/molecule/default/verify.yml)
```yaml
    - name: Get all kubeapps running pods.
      command: kubectl get pods -n kubeapps
      changed_when: false
      register: kubeapps_pods

    - name: Get kubeapps pods
      ansible.builtin.set_fact:
        kubeapps_running: "{{ kubeapps_pods.stdout.split('\n') | 
          reject('search', 'NAMESPACE') | 
          select('search', 'Running') | list }}"

    - name: Print list of kubeapps pods.
      debug: var=kubeapps_running

    - name: Assert kubeapps all pods running
      ansible.builtin.assert:
        that: "{{ (kubeapps_running | 
          select('search', '1/1') | list) | length == 10 }}"


```

Voici la commande molecule qui permettra de faire ceci une fois notre playbook utilisable :

```bash
molecule test --destroy never -- -t kubeapps
```

Si votre playbook est déjà passé en entier un `molecule verify` va suffire pour jouer le playbook `verify.yml`.

Vous devriez voir passer les assertions et les autres tâches sans problèmes.

```
node-0                     : ok=15 ...
```

### Dnsmasq pour obtenir utiliser des bons liens vers l'interface

 l'objectif va être de pouvoir utiliser des domaines de test en local. Par exemple on veut utiliser kubeapps.svc.test pour accèder à l'api de notre cluster kubernetes.

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
echo 'address=/.local/127.0.0.1' >> $DNSMASQ_CNF_DIR
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
  domain   : dev
  nameserver[0] : 127.0.0.1
```
Et voilà normalement vous devriez accèder à kubeapps depuis chrome avec [http://kubeapps.svc.dev/](http://kubeapps.svc.dev/)

### H. Tls avec cert manager (et local)

#### Faire confiance à notre autorité de certification de test

- `curl -k https://localhost:32444/roots/0 > ~/Downloads/pebble-ca.pem`

#### On Mac it is not much work see here

- Open Keychain Access
- File > import items...
- Select ~/Downloads/pebble-ca.pem
- Right click on minica root ca choose get info
- Open Trust and select Always Trust on When using this certificate

#### Sur Linux

```
sudo cp ~/Downloads/pebble-ca.pem /usr/local/share/ca-certificates/pebble-ca.pem
sudo chmod 644 /usr/local/share/ca-certificates/pebble-ca.pem
sudo update-ca-certificates
```

***After close the web page and re open it. Https should be enabled***

### H. Une authentification et des habilitations fine pour kubeapps

Pour plus d'**Info**s : https://oauth2-proxy.github.io/oauth2-proxy/docs/configuration/oauth_provider#github-auth-provider

Nous allons adapter le rôle en vue de cette fois ci le rendre utilisable par un playbook de pré-production.

> [playbook/roles/kubeapps/defaults/main.yml](playbook/roles/kubeapps/defaults/main.yml) **ligne 18 jusqu'à la fin**

```yaml
# ...
# Authentication to kubeapps
kubeapps_github_org: ""
kubeapps_github_team: ""
kubeapps_github_extra_flags: 
  - --email-domain=*
  - --github-org="{{ kubeapps_github_org }}"
  - --github-team="{{ kubeapps_github_team }}"

kubeapps_authProxy: {}
kubeapps_authProxy_default:
  enabled: false
  provider: github
  clientID: ""
  clientSecret: ""
  # default to result of echo "not-good-secret" | base64
  cookieSecret: bm90LWdvb2Qtc2VjcmV0Cg==
  extraFlags: "{{ kubeapps_github_extra_flags }}"
# Merge user config with defaults
kubeapps_authProxy_final: "{{ kubeapps_authProxy_default + kubeapps_authProxy }}"

```

[playbook/roles/kubeapps/templates/kubeapps-chart-crd.yml.j2](playbook/roles/kubeapps/templates/kubeapps-chart-crd.yml.j2) **ligne 19**
```yaml
    authProxy:
      {{ kubeapps_authProxy_final | to_nice_yaml | indent(width=6) -}}
```

Par défaut si on relance notre test molecule nous n'aurons pas d'activation de l'authentificaiton avec github. Nous allons donc pour cette fois faire un test manuelle de celle-ci car elle dépend de configuration propre à une production soit tls activé que kubeapps soit disponible en ligne. (obligation en terme de sécurité de oauth2 / github)


note manifest extrait
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

### I. Configuration de notre organisation github et application oauth

Créer une nouvelle organisation [ici](https://github.com/account/organizations/new) :

- Sélectionner le free plan
- Choisissez un nom à l'organisation
- Renseignez votre email
- Cocher bien que elle vous appartient (rattaché à votre pseudo github)

> On peut créer une équipe particulière dans notre organisation qui pourra avoir accès à kubeapps. Le Lien vers le formulaire de création ressemble à ça : https://github.com/orgs/nom-de-ton-organisation/new-team.

> Nommez là comme vous voulez. On pourra la configurer avec la variable `kubeapps_github_team`.

#### Créer l'application github

[créer votre application ici](https://github.com/organizations/<my-org>/settings/applications/new)

Configuré la comme ceci **pour l'instant** en utilisant les url en local qui ne fonctionnerons pas (pas de tls activé / ni online)

- Application name : `kubeapps_test`
- Homepage URL : `https://kubeapps.k3s.local`
- Application description (optionel): `test kubeapps`
- Authorization callback URL : `https://kubeapps.k3s.local/oauth2/callback`

Ensuite noté bien votre **Client Id** et générer un nouveau **Client secret** que vous devez aussi conserver pour la prochaine étape.

#### Connecter notre application oauth 2 à Dex IDP

- [restart k3s handler](https://github.com/PyratLabs/ansible-role-k3s/blob/dae3eb928eb85960c6fc3f8bf1806578d4d1dfd9/handlers/main.yml#L28)

### J. Playbook et inventaire final

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

#### Configurer notre rôle avec notre application github

Nous allons crypter les **Info**rmations dangereuses dans un vault ansible que l'on pourra créer avec :

```bash
ansible-vault create inventories/k8s-paas/group_vars/secrets
```

#### Tester l'authentification github


> `--tag kubeapps` permet de choisir uniquement de lancer les tâches que l'on a bien taggé kubeapps pour gagner du temps


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

> **Info**: recommandation : extension `4ops.packer`

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
