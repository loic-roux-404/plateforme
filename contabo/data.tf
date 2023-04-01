data "github_organization" "org" {
  name = var.github_organization
}

data "github_membership" "all" {
  for_each = toset(data.github_organization.org.members)
  username = each.value
}

data "github_membership" "all_admin" {
  for_each = {
    for _, member in data.github_membership.all :
    _ => member if member.role == "admin"
  }
  username = each.value.username
}

data "contabo_instance" "paas_instance" {
  id = var.contabo_instance
}
