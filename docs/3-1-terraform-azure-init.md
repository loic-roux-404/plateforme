<div style="display: flex; width: 100%; text-align: center;">
<h3 style="width: 20%">

[Précédent](2-packer-playbook.md)
</h3>

<div style="width: 35%"></div>

<h3 style="width: 40%">

[Suivant - Sécurisation de l'organisation](3-2-terraform-security.md)
</h3>
</div>

---

## 3-1 Initialisation du déploiement final sur Azure avec Terraform

Ici nous mettons en place le déploiement final sur Azure avec  l'outil d'infrastructure as code Terraform.

### Obtenir un nom de domaine gratuit (étudiants)

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

[infra/variables.tf](../infra/variables.tf)

```tf


variable "github_organization" {
  type = string
}

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

variable "domain_ttl" {
  type = number
  default = 3000
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

[infra/example.tfvars.dist](../infra/exemple.tfvars.dist)

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

---

<div style="display: flex; width: 100%; text-align: center;">
<h3 style="width: 20%">

[Recommencer](#3-1-Initialisation-du-déploiement-final-sur-Azure-avec-Terraform)
</h3>

<div style="width: 35%"></div>

<h3 style="width: 40%">

[Suivant - Sécurisation de l'organisation](3-2-terraform-security.md)
</h3>
</div>
