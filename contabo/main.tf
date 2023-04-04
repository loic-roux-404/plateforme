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

# Dex oidc client
resource "random_password" "dex_client_id" {
  length  = 16
  special = false
}

resource "random_password" "dex_client_secret" {
  length  = 24
  special = false
}

resource "random_password" "cert_manager_private_key_secret" {
  length  = 12
  special = false
}

locals {
  ssh_connection = merge(var.ssh_connection, {
    public_key  = trimspace(file(pathexpand(var.ssh_connection.public_key)))
    private_key = trimspace(file(pathexpand(var.ssh_connection.private_key)))
  })
  ansible_vars = merge(
    var.ansible_secrets,
    {
      dex_client_id                   = random_password.dex_client_id.result
      dex_client_secret               = random_password.dex_client_secret.result
      waypoint_base_domain            = var.domain
      dex_github_client_org           = data.github_organization.org.orgname
      dex_github_client_team          = github_team.opsteam.name
      cert_manager_private_key_secret = random_password.cert_manager_private_key_secret.result
      cert_manager_letsencrypt_env    = var.cert_manager_letsencrypt_env
    }
  )
}

# Store secrets to recover them later
resource "contabo_secret" "paas_instance_ssh_key" {
  name  = "paas_instance_ssh_key"
  type  = "ssh"
  value = local.ssh_connection.public_key
}

resource "contabo_secret" "paas_instance_password" {
  name  = "paas_instance_password"
  type  = "password"
  value = local.ssh_connection.password
}

############
# Vm
############

locals {
  iso_version_file = "ubuntu-${var.ubuntu_release_info.name}-${var.ubuntu_release_info.version}.${var.ubuntu_release_info.format}"
}

resource "contabo_image" "paas_instance_qcow2" {
  name        = var.ubuntu_release_info.name
  image_url   = "${var.ubuntu_release_info.url}/${var.ubuntu_release_info.iso_version_tag}/${local.iso_version_file}"
  os_type     = "Linux"
  version     = var.ubuntu_release_info.iso_version_tag
  description = "generated PaaS vm image with packer"
}

resource "time_sleep" "wait_image" {
  depends_on = [contabo_image.paas_instance_qcow2]
  create_duration = "4m"

  triggers = {
    status = contabo_image.paas_instance_qcow2.status
    id = contabo_image.paas_instance_qcow2.id
  }
}

resource "contabo_instance" "paas_instance" {

  depends_on = [
    github_team_membership.opsteam_members,
  ]

  display_name = "ubuntu-k3s-paas"
  image_id     = time_sleep.wait_image.triggers["id"]
  ssh_keys     = [contabo_secret.paas_instance_ssh_key.id]
  user_data = sensitive(templatefile(
    "${path.root}/user-data.yaml.tmpl",
    {
      tailscale_key       = var.tailscale_key
      ubuntu_release_info = var.ubuntu_release_info
      ssh_connection      = local.ssh_connection
      ansible_vars = [
        for k, v in local.ansible_vars : "${k}=${v}"
      ]
    }
  ))
}

resource "terraform_data" "paas_instance_wait_bootstrap" {
  triggers_replace = [
    contabo_instance.paas_instance.id
  ]

  connection {
    type        = "ssh"
    user        = local.ssh_connection.user
    private_key = local.ssh_connection.private_key
    host        = contabo_instance.paas_instance.ip_config[0].v4[0].ip
  }

  provisioner "remote-exec" {
    on_failure = fail
    inline = [
      "sudo cloud-init status --wait && sudo cloud-init clean"
    ]
  }
}

resource "namedotcom_record" "dns_zone" {
  depends_on = [
    terraform_data.paas_instance_wait_bootstrap
  ]
  for_each    = toset(["", "*"])
  domain_name = var.domain
  host        = each.key
  record_type = "A"
  answer      = contabo_instance.paas_instance.ip_config[0].v4[0].ip
}
