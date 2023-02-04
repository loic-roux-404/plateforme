# 3.3 Machine virtuelle et réseau

#### Création de l'environnement réseau

Ces directives sont essentiellement tirées de la documentation officielle de terraform pour azure. Il faut savoir que l'usage d'azure pour créer une machine nous indique l'utilisation d'un réseau virtuel (DHCP) et d'un sous-réseau afin de la rendre accessible avec une adresse IP privée.

`azurerm_virtual_network` et `azurerm_subnet` nous permettent de faire ça facilement dans notre groupe de ressources.

```tf linenums="97" title="infra/main.tf"
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

```tf linenums="114" title="infra/main.tf"
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

```tf linenums="149" title="infra/main.tf"
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

Azure a de très bons outils pour la gestion des zones dns. On va donc utiliser le provider `azurerm` pour créer une zone et récupérer les serveurs dns associés.

```tf linenums="171" title="infra/main.tf"
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

```tf linenums="179" title="infra/main.tf"
resource "namedotcom_domain_nameservers" "namedotcom_paas_ns" {
  domain_name = var.domain
  nameservers = [
    # Delete ending dot which isn't valid for namedotcom api
    for item in azurerm_dns_zone.paas.name_servers : trimsuffix(item, ".")
  ]
}
```

Enfin on met en place le **wildcard** pour la zone dns afin que tous les sous domaines pointent vers l'ip publique de la vm. Ainsi n'importe quel sous domaine de `paas-exemple-tutorial.live` pointera vers l'ingress de k3s.

```tf linenums="187" title="infra/main.tf"
resource "azurerm_dns_a_record" "paas" {
  depends_on = [namedotcom_domain_nameservers.namedotcom_paas_ns]
  name                = "*"
  zone_name           = azurerm_dns_zone.paas.name
  resource_group_name = data.azurerm_resource_group.paas.name
  ttl                 = var.domain_ttl
  target_resource_id  = azurerm_public_ip.paas.id
}

```

> Warning: N'oublions pas de relié les ressources namedotcom et azure avec `depends_on`, car ce sont deux fournisseurs de services différents. On évite ainsi des problèmes de synchronisation DNS.

C'est comme cela que l'on arrive à avoir un nom de domaine comme `kubeapps.paas-exemple-tutorial.live` qui pointe vers l'ingress de k3s.

---


#### Création de l'identité de la vm

```tf linenums="195" title="infra/main.tf"
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

- La ressource `azurerm_user_assigned_identity` permet de créer une identité et d'ensuite accéder à ses informations de connexion (tenant, service principal...)

- `azurerm_key_vault_access_policy` défini les permissions de l'identité sur le keyvault. Ici on lui donne les droits de lecture sur les secrets. `key_vault_id` est obligatoire pour lier la politique au keyvault.

#### Création de la VM

```hcl linenums="223" title="infra/main.tf"
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

```hcl linenums="5" title="infra/data.tf"
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

On rappelé que `vault_url` est une variable qui contient l'url du keyvault azure et que l'on va l'utiliser avec ansible et le plugin lookup [`azure_keyvault_secret`](https://docs.ansible.com/ansible/devel/collections/azure/azcollection/azure_keyvault_secret_lookup.html) pour récupérer les secrets.

> **Note** L'inventaire [playbook/inventories](playbook/inventories) a été créer dans les étapes précédentes et se trouve dans notre image créer avec `packer`

```tf linenums="259" title="infra/main.tf"
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

```yaml linenums="1" title="infra/cloud-init.yml"
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
