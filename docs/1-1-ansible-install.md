# 1.1  Provisionning du paas avec ansible

---

Cette partie très longue présente comment créer le rôle ansible qui va permettre de provisionner un cluster kubernetes sur un serveur linux puis d'y mettre en place la solution de PaaS.

L'objectif d'ansible est de déployer des configurations et des outils sur des machines. À l'aide d'un format de configuration simple
proche de l'algorithmie, nous pourrons amener tous les outils indispensables à la création de notre PaaS.


### Installer ansible et création du rôle

Ansible est un outil dépendant de l'écosystème python. Pour simplifier la gestion des dépendances 
qui risquent de faire conflit avec d'autres installations
de python, nous allons utiliser `miniconda` installé précédemment.

Molecule est un outil permettant de tester nos suites de configurations ansible contenus dans des rôles ou des tâches.

Créer votre espace de travail :

```bash
cd ~
mkdir paas-tutorial/
```

Ensuite on initialise un environnement virtuel python avec sa propre version de **python 3.9** et les dépendances ansible et molecule. Ainsi nos dépendances n'entrent pas en conflit avec d'autres pouvant être incompatible.

```bash
conda create -n playbook-paas python=3.9
conda activate playbook-paas
```

Installer ansible et molecule préconfiguré pour utiliser docker (rancher desktop).
```bash
pip install 'ansible==6.5.0' 'molecule[docker]'
```

**Sur windows** lancez cette commande pour avoir accès aux dépendances python directement.

```zsh 
# ~/.bashrc si vous utiliser bash 
echo "export PATH=\"$PATH:${HOME}/.local/bin\"" >> ~/.zshrc
```

Vérifier que tous fonctionne avec `ansible --version`.

Vous devriez avoir `ansible [core 2.13.4]` dans le retour

### **Bonus** pour faire fonctionner l'extension VsCode ansible

> **Warning**: Utilisateur du WSL **Pour utiliser vscode, utilisez le impérativement via la ligne de commande linux WSL dans votre projet `~/paas-tutorial`** : `code .`

> Vscode : `.vscode/settings.json`
> Remplacez bien le chemin avec le résultat de cette commande `which python`
> miniconda sur wsl, mambaforge sur mac
```json
{
    "ansible.python.interpreterPath": "<User-Path>/mambaforge/envs/playbook-paas/bin/python"
}
```

### B. Playbook ansible

Un playbook ansible est un projet chargé de lancer plusieurs rôles différents sur des machines disponibles sur le réseau via **ssh**. (localhost par exemple peut être provisioné).

Pour aller plus loin dans le fonctionnement de ansible, cet outil s'appuie intégralement sur l'environnement python installé sur une machine invités (que l'on provisionne). Grâce à python ansible va abstraire la complexité de l'administration système linux avec des **déclarations yaml**, des **templates** pour créer des fichiers dynamiquement, des **structures de contrôles** algorithmique et des variables manipulables avec des **filters**.

#### On Commence :

On va créer un dossier playbook pour mettre tout ce qui concerne ansible

Aussi, on va geler les versions des dépendances dans un fichier requirements pour qu'un autre environnement puisse facilement retrouver l'état de votre installation sans problèmes de compatibilités.

```sh
mkdir -p paas-tutorial/playbook
cd paas-tutorial/playbook

```

Geler les dépendances pour éviter des soucis de compatibilité plus tard.

```bash
pip freeze | grep -E "ansible|molecule" > requirements.txt
```

> Nous allons suivre **l'alternative-directory-layout** recommandé par cette [documentation](https://docs.ansible.com/ansible/latest/user_guide/sample_setup.html#alternative-directory-layout)

Voici la suite complète de commande pour créer la structure du playbook.

```bash

touch site.yml
touch requirements.yaml

mkdir roles/
```

Ensuite dans `requirements.yaml` on importe les roles que l'on utilise en dépendances.

> Ansible galaxy est le gestionnaire de paquet pour importer des rôles et des collections ansible dans un playbook.

> **Note** pour l'instant, il y a un bug avec galaxy nous empêchant de récupérer la bonne version de k3s. On peut forcer l'utilisation directe de git pour récupérer la version 3.3.0

```yaml linenums="1" title="playbook/requirements.yaml"
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

Les **roles** correspondent à des suites de tâches qui vont installer et configurer un outil sur une machine. Ici on utilisera un [role k3s](https://github.com/PyratLabs/ansible-role-k3s) qui s'occupe de configurer en fonction de nos paramètres le cluster k3s.

> **Note** K3s n'utilise pas `docker` mais `containerd` pour utiliser les fonctionnalités de conteneur linux.

Pour installer ces `requirements` maintenant on lance dans le dossier `playbook/` :

```bash
ansible-galaxy install -r requirements.yaml
```

Normalement tous est installé correctement et prêt à l'emploi.

### C. Initialiser le rôle installant un Cluster kubernetes (k3s) 

Pour suivre la convention d'ansible nous allons procéder en créant un rôle. Il sera ici interne à notre projet pour simplifier, mais on peut imaginer facilement le déplacer dans un autre repository.
Son objectif sera d'installer un ensemble de solutions pour faire fonctionner kubeapps.

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

Voici ce que va être rendu comme structure de [**rôle**](https://docs.ansible.com/ansible/latest/user_guide/playbooks_reuse_roles.html).

Nous allons ensuite mettre à jour les métadonnées ansible galaxy avec notamment la dépendance kubernetes (rôle k3s). Il y a déjà du contenu présent, ne supprimer rien et ajouter à la ligne 51 la case du tableau `dependencies`.

```yaml linenums="51" title="playbook/roles/kubeapps/meta/main.yml"
dependencies:
    - src: xanmanning.k3s
      version: v3.3.0
      vars:
        k3s_release_version: v1.21
```

> `k3s_release_version` est indispensable de ne pas monter au-dessus de la version `1.21`. Dans le contexte docker in docker, il y a des problèmes de compatibilité avec les fonctionnalités linux récentes (QOS, cgroups, ...).

Ensuite vous devez obligatoirement définir ces Informations sur les metas du rôles:

```yaml linenums="1" title="playbook/roles/kubeapps/meta/main.yml"
galaxy_info:
  author: loic-roux-404
  namespace: paas_tutorial
  description: kubeapps deployment
  role_name: kubeapps
```

Le rôle kubernetes se lancera donc directement avant les tâches de celui de kubeapps.

---
