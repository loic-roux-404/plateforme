# Paas Tutorial

## Requis

- Un PC / Mac peut importe l'OS
- Des bases d'administration linux
- Un minimum de culture sur les systèmes d'Information
- Connaissance des concepts d'environnements isolés linux ou **containers**
- Un compte [github](http://github.com/)
- Un compte [azure](https://azure.microsoft.com/fr-fr/) avec le crédit de 100$ offert pour les étudiants (avec l'email myges cela fonctionne normalement)
- Valider votre compte github student pour ne pas avoir à acheter de nom de domaine [https://education.github.com/globalcampus/student](https://education.github.com/globalcampus/student), valider le compte avec votre adresse mail de l'université.

## Introduction

L'objectif de ce tutoriel est de vous permettre de créer sur une petite machine ou sur un serveur personnel un PaaS (Platform as a service) vous permettant de déployer des applications en microservices. Celui-ci sera basé sur [kubernetes](https://kubernetes.io/fr/) pour la conteneurisation et [Kubeapps](https://kubeapps.dev/) pour l'interface de déploiement. En bonus si le temps nous le permet on utilisera concourse pour ajouter l'automatisation des mise à jour de l'application.

L'optique de cet outillage suivra :
- le principle **d'immutable infrastructure** avec l'idée de recréer plutôt que de mettre à jour. Ainsi nous aurons recour à des iso linux déjà prêt pour déployer la plateforme **kubernetes** / **kubeapps** directement sur un serveur.

- Le principe **d'infrastructure as code** en gardant toutes la spécification de notre infrastructure dans des configurations et scripts.

Pour cela nous ferons appel à un socle technique composé de :
- l'outil [`k3s`](https://k3s.io/) qui simplifie l'installation de kubernetes sur des machines ARM tout en restant compatible avec les architectures classiques X64. Il fourni par défaut des pods (containers en execution) pour inclure des fonctionnalités souvent recherchés sur ce type de configuration edge computing. (reverse proxy, configuration DNS...)
- [¨Packer](https://www.packer.io/) pour créer des images iso de machine linux
- [Ansible](https://www.ansible.com/) pour provisioner cette image
- [Azure](https://azure.microsoft.com/fr-fr/) pour nous founir des serveurs accessible en ssh sur lequels nous pourrons mettre en ligne

## Installation de Docker

Pour utilisateurs de **windows** il faut un [**WSL**](https://learn.microsoft.com/fr-fr/windows/wsl/install). 

- Télécharger après avoir suivi cette documentation la distribution linux ``Ubuntu 20.04.5 LTS`` depuis le windows store. 
- **+ Windows terminal bien que pas obligatoire il est très pratique pour accèder au shell**

Ensuite dans vscode installer l'extension wsl `ms-vscode-remote.remote-wsl`.

[**Rancher**](https://rancherdesktop.io/) l'alternative mieux configurée et sans soucis de license à docker desktop. Il est portable sur windows et mac et nous permet d'avoir une expérience docker complète et fonctionnelle sur notre machine.

Dans les choix proposés dans la mise en place :
- **Décocher kubernetes**
- Choisissez **dockerd** comme moteur de conteneurisation

Laissez le ensuite finir de s'initialiser.

## Installation de l'environnement python

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

---

<h3 style="text-align: center;">

[Suivant - Rôle Ansible](1-ansible-role.md)

</h3>
