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

############
# Security
############

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

resource "random_password" "vm_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "contabo_secret" "paas_instance_ssh_key" {
  name  = "paas_instance_ssh_key"
  type  = "ssh"
  value = file(pathexpand(var.ssh_public_key))
}

locals {
  final_secrets = merge(
    var.secrets,
    {
      dex_client_id                      = random_password.dex_client_id.result
      dex_client_secret                  = random_password.dex_client_secret.result
      kubeapps_oauth_proxy_cookie_secret = random_password.kubeapps_oauth_proxy_cookie_secret.result
    }
  )
}

############
# Vm
############

locals {
  ansible_vars = merge(
    local.final_secrets,
    {
      kubeapps_hostname            = "kubeapps.${var.domain}"
      dex_hostname                 = "dex.${var.domain}"
      dex_github_client_org        = data.github_organization.org.orgname
      dex_github_client_team       = github_team.opsteam.name
      cert_manager_letsencrypt_env = var.cert_manager_letsencrypt_env
    }
  )
}

resource "contabo_image" "paas_instance" {
  name        = "ubuntu_paas"
  image_url   = var.os_image_url
  os_type     = "Linux"
  version     = "22.04.2"
  description = "generated PaaS vm image with packer"
}

resource "contabo_instance" "paas_instance" {
  image_id = contabo_image.paas_instance.id
  ssh_keys = [contabo_secret.paas_instance_ssh_key.id]
}

resource "namedotcom_record" "dns_zone" {
  for_each = toset(["", "*"])
  domain_name = var.domain
  host        = each.key
  record_type = "A"
  answer      = contabo_instance.paas_instance.ip_config[0].v4[0].ip
}

resource "contabo_instance" "paas_instance" {
  user_data = templatefile(
    "${path.module}/cloud-init.yaml",
    {
      ansible_vars = local.ansible_vars
    }
  )
}
