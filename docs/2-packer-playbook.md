# 2. Utilisation de notre rôle dans packer

---

On va ici pré-provisionner une machine virtuelle dans une image azure ARM. On utilisera un playbook appelant le rôle kubeapps sans installer les pods qui ont besoin du réseau externe pour fonctionner. (cert-manager, dex et kubeapps)

#### Playbook et inventaire final

Nous allons adapter le rôle en vue de cette fois ci le rendre utilisable par un playbook de préproduction.

Nous allons créer le fichier `site.yaml` (dans le dossier `playbook/`) qui va se charger avec la commande `ansible-playbook` de lancer les rôles dans le bon ordre sur les machines.

Cette étape servira pour utiliser le playbook dans la [partie 2](#2-créer-une-première-image-virtuelle-pour-le-test) avec packer

```yaml linenums="1" title="playbook/site.yaml"
---
- hosts: all
  gather_facts: True
  become: True
  pre_tasks:
    - include_tasks: roles/kubeapps/tasks/pre-import-cert.yml
      when: cert_manager_is_internal  
  roles:
    - role: roles/kubeapps

```

> `include_tasks..` : comme pour le playbook converge dans les tests on doit importer un certificat pour faire confiance à un Lets-encrypt de test.

Ensuite on crée notre inventaire pour azure dans un dossier `playbook/inventories/azure/`. Un inventaire ansible est constitué d'un groupe de variables (dossier `group_vars`) et d'un fichier `hosts` qui va contenir les machines sur lesquelles on va jouer le playbook.

```bash
mkdir -p playbook/inventories/azure/group_vars
```

Ces variables de groupes font appel à un plugin `lookup` permettant de lire les secrets d'une ressource keyvault que l'on configurera dans la partie terraform.

On peut ajouter l'installation de la collection dans les requirements du playbook si ce n'est pas déjà fait.

```yaml linenums="1" title="playbook/inventories/azure/group_vars/all.yml"
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

> **Note** Nous n'aurons pas besoin d'utiliser les variables de connexion du plugin. Comme nous serons sur une machine azure, celle-ci aura les habilitations requises pour accéder directement aux secrets.

Puis on définit un fichier `hosts` pointant directement sur localhost. 

```ini linenums="1" title="playbook/inventories/azure/hosts"
127.0.0.1
```

Nous allons rester sur localhost avec un provision sur la machine même dans les prochaines étapes packer et terraform.

## Build packer

Maintenant que nous savons que notre playbook est fonctionnel nous allons l'intégrer dans la chaine de création de notre image.
Nous passerons donc par l'outil packer de hashicorp une des références dans les infrastructures cloud moderne.

L'objectif est d'utiliser les installations précédentes sur une distribution linux générique pour la rendre prête à l'emploi.

Voici comment le flux de création d'une VM avec packer s'organise :

1. Validation et parsing d'une **configuration** [HCL](https://github.com/hashicorp/hcl)

1. Lancement d'un plugin **builder** en fonction de notre infrastructure. Par exemple on peut build des images docker, virtualbox mais aussi des images dédiées à des clouds comme Azure (celui que nous avons choisi).

1. Le plugin créer, initialise les composants système majeurs de la machine puis démarre automatiquement la machine.

1. Une fois la machine prête un système de **communicator** est disponible et nous pouvons lancer des commandes sur celle-ci. Nous utiliserons evidemment SSH.

1. Des **provisionners** sont ensuite joués pour configurer la machine. Nous utiliserons à cette étape le plugin ansible qui va nous permettre d'utiliser le travail précédent.

1. Enfin des **post processors** vont effectuer des traitements après le build une fois l'Iso rendu. Par exemple nous pourrons upload **l'artifact** sur un registre comme [HCP](https://cloud.hashicorp.com/products/packer) ou sur un service comme [Azure resource manager](https://learn.microsoft.com/fr-fr/azure/azure-resource-manager/management/overview)

### A. Sources

- [packer docs](https://www.packer.io/docs)
- [packer on ci](https://www.packer.io/guides/packer-on-cicd/pipelineing-builds)
- [authentication](https://www.packer.io/plugins/builders/azure#authentication-for-azure)
- [Arm](https://www.packer.io/plugins/builders/azure/arm)

### Installation

Pour installer packer [c'est ici](https://www.packer.io/downloads)

> **Note**: recommandation : extension `szTheory.vscode-packer-powertools` (elle contient un bon formateur de fichier HCL), `hashicorp.hcl`.

Vérifier que packer 1.8+ est bien installé dans votre ligne de commande :
```sh
packer --version

```

Puis nous avons besoin de la ligne commande de azure pour créer notre service principal. Pour cela il faut installer le [CLI azure](https://docs.microsoft.com/fr-fr/cli/azure/install-azure-cli)

Connectez-vous avec **`az login`** à votre compte azure.

> **Note** Vous devez avoir un abonnement azure avec du crédit disponible. (exemple : essai de 200$ offert)

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

Les variables de configuration et leurs valeurs par défaut :

```hcl linenums="1" title="infra/ubuntu.pkr.hcl"
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

> Note: le fichier `vars.json` sert à passer de nouvelles valeurs pour ces variables avec `packer build -var-file=vars.json ubuntu.pkr.hcl`

```hcl linenums="16" title="infra/ubuntu.pkr.hcl"
source "azure-arm" "vm" {
  use_azure_cli_auth = true

  managed_image_name                = "k3s-pre-paas-az-arm"
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

```hcl linenums="31" title="infra/ubuntu.pkr.hcl"

build {

  sources = ["sources.azure-arm.vm"]

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

> **Note**: le provisionner shell est nécessaire pour nettoyer l'agent azure qui est installé par défaut sur les images automatiquement générées par ce cloud.

Toujours dans `infra/`, on lance le traitement entier avec packer :

```bash
packer build ubuntu.pkr.hcl
```

Vous pourrez voir le résultat de la création de l'image dans le portail azure dans votre groupe de ressource `kubeapps-group`.

---
