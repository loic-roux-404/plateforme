# 3.3 Réseau

#### Création de l'environnement réseau

Ces directives sont essentiellement tirées de la documentation officielle de terraform pour azure. Il faut savoir que l'usage d'azure pour créer une machine nous indique l'utilisation d'un réseau virtuel (DHCP) et d'un sous-réseau afin de la rendre accessible avec une addresse IP privée.

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

Azure a de très bon outils pour la gestion des zones dns. On va donc utiliser le provider `azurerm` pour créer une zone et récupérer les serveurs dns associés.

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
  name                = "*"
  zone_name           = azurerm_dns_zone.paas.name
  resource_group_name = data.azurerm_resource_group.paas.name
  ttl                 = var.domain_ttl
  target_resource_id  = azurerm_public_ip.paas.id
}

```

C'est comme cela que l'on arrive à avoir un nom de domaine comme `kubeapps.paas-exemple-tutorial.live` qui pointe vers l'ingress de k3s.

---
