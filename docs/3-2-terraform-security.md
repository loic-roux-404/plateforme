# 3.2 Sécurisation de l'organisation

---

#### Création du key vault et des secrets

- [terraform keyvault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret)

- [keyvault azure](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/tutorial-windows-vm-access-nonaad#grant-access)

Dans le datasource `data.tf` nous allons récupérer les membres de l'organisation github et les membres admin de notre organisation.
Nous utilisons des boucles pour remplir les dictionnaires `github_membership.all` et `github_membership.all_admin`

```tf  linenums="13" title="infra/data.tf"
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

```tf  linenums="1" title="infra/main.tf"
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

Pour des raisons essentielles de sécurité nous mettons à disposition de la machine virtuelle un stockage de secrets sécurisé grâce à la ressource terraform `azurerm_key_vault`

```tf linenums="17" title="infra/main.tf"
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

`soft_delete_retention_days` permet de définir le nombre de jours pendant lesquels des secrets supprimés pourront être restaurés.

`tenant_id` permet de définir le propriétaire du keyvault.

Ensuite nous utilisons des propriétés de base pour rendre les secrets accessibles pour différents types d'utilisations, définir le type de keyvault et son cycle de vie.

Le block `lifecycle` est une fonctionnalité de terraform qui change la façon dont est recréer la ressource avant une modification.

Enfin le plus important est le block `access_policy` qui permet de définir les permissions de l'utilisateur qui va accéder au keyvault. Ici on les définit pour le `tenant id` et le `principal id` contenus dans le client azure courant (utilisateur connecté avec azure cli).

##### Utilisons maintenant le keyvault pour stocker nos secrets

Pour stocker nos secrets, nous utilisons la ressource `azurerm_key_vault_secret` qui permet de stocker des secrets dans le keyvault créé précédemment. Nous allons utiliser les secrets créer dans `variables.tf` ainsi que des mots de passes générés aléatoirement pour certaines configurations de `dex` et `kubeapps`.

```tf linenums="53" title="infra/main.tf"
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

---
