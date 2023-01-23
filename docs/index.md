# Tutoriel PaaS

![résultat](images/result.gif)

### Architecture

![archi](images/archi.jpg)

## Requis pour suivre le tutoriel

### Matériel et outils

- Un PC / Mac peu importe l'OS (PC risque d'être instable)
- Un compte [github](http://github.com/)
- Un compte [azure](https://azure.microsoft.com/fr-fr/) avec le crédit de 100$ offert pour les étudiants (avec l'email myges cela fonctionne normalement)
- Valider votre compte [github student](https://education.github.com/globalcampus/student) pour ne pas avoir à acheter de nom de domaine. Pour valider utilisez votre adresse mail de l'université.
- Un compte [docker hub](https://hub.docker.com/)

### Compétences
- Des bases d'administration système et réseau linux
- Algorithmie et programmation sur au moins un langage
- Des bases sur les certificats "Secure socket layer" et leur utilisation de la cryptographie asymétrique
- Connaissance du langage de configuration `yaml`
- Culture sur les infrastructures de déploiement multienvironnements (staging, prod)
- Connaissance des concepts d'environnements isolés linux ou **containers**
- L'outil de gestion de version Git l'hôte git **github**

## Sommaire

- [0. Installation](0-install.md)
- [1. Rôle ansible](#sommaire)
    - [1.1 Provisionning du paas avec ansible](1-1-ansible-install.md)
    - [1.2 Présentation de K3s et installation](1-2-ansible-k3s.md)
    - [1.3 Installation des manifests (algo)](1-3-ansible-manifests.md)
    - [1.4 Autorité de certification](1-4-ansible-pebble.md)
    - [1.5 Mise en place des communications réseau du cluster](1-5-ansible-dns.md)
    - [1.6 Utiliser notre autorité avec cert-manager](1-6-ansible-cert-manager.md)
    - [1.7 Faire confiance à notre autorité de certification](1-7-ansible-trust-ca.md)
    - [1.8 Authentification et des habilitations](1-8-ansible-dex.md)
    - [1.9 Kubeapps](1-9-ansible-kubeapps.md)
- [2. Packer](2-packer-playbook.md)
- [3. Terraform / Azure](#sommaire)
    - [3.1 Initialisation du déploiement final sur Azure avec Terraform](3-1-terraform-azure-init.md)
    - [3.2 Sécurisation de l'organisation](3-2-terraform-security.md)
    - [3.3 Réseau](3-3-terraform-azure-network.md)
    - [3.4 Machine virtuelle](3-4-terraform-azure-vm.md)
- [4. Helm chart du microservice](#sommaire)
    - [4.1 Création du Helm chart](4-1-helm-chart.md)
    - [4.2 4.2 Déploiement du chart](4-2-helm-chart-deploy.md)

- [5. FAQ et exercices](5-allez-plus-loin.md)
