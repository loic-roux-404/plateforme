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
  role     = "maintainer"
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
  min_upper = 1
  min_numeric = 3
  min_special = 1
}

resource "contabo_secret" "paas_instance_ssh_key" {
  name  = "paas_instance_ssh_key"
  type  = "ssh"
  value = file(pathexpand(var.ssh_public_key))
}

resource "contabo_secret" "paas_instance_root_password" {
  name  = "paas_instance_root_password"
  type  = "password"
  value = random_password.vm_password.result
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
  iso_version_file = "ubuntu-${var.ubuntu_release_info.name}-${var.ubuntu_release_info.version}.${var.ubuntu_release_info.format}"
}

resource "contabo_image" "paas_instance" {
  name        = var.ubuntu_release_info.name
  image_url   = "${var.ubuntu_release_info.url}/${var.ubuntu_release_info.iso_version_tag}/${local.iso_version_file}"
  os_type     = "Linux"
  version     = var.ubuntu_release_info.iso_version_tag
  description = "generated PaaS vm image with packer"
}

resource "namedotcom_record" "dns_zone" {
  for_each    = toset(["", "*"])
  domain_name = var.domain
  host        = each.key
  record_type = "A"
  answer      = data.contabo_instance.paas_instance.ip_config[0].v4[0].ip
}

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

resource "contabo_instance" "paas_instance" {
  image_id = contabo_image.paas_instance.id
  ssh_keys = [contabo_secret.paas_instance_ssh_key.id]
  root_password = contabo_secret.paas_instance_root_password.id
  user_data = templatefile(
    "${path.module}/cloud-init.yaml",
    {
      iso_version_tag = var.ubuntu_release_info.iso_version_tag
      ansible_vars = [
        for config_key, config_value in local.ansible_vars : "${config_key}=${config_value}"
      ]
    }
  )
  depends_on = [
    namedotcom_record.dns_zone,
    github_team_membership.opsteam_members,
  ]
}
