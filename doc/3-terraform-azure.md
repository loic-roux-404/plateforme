## Déploiement final sur Azure avec Terraform

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

---

<h3 style="text-align: center;">

[Suivant - Faq et exercices](4-allez-plus-loin.md)

</h3>
