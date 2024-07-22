data "github_organization" "org" {
  name = var.github_organization
}

locals {
  admins = {
    for _, member in data.github_organization.org.users :
    _ => member.login if lower(member.role) == "admin"
  }
}

resource "github_team" "opsteam" {
  name        = var.github_team
  description = "This is the production team"
  privacy     = "closed"
}

resource "github_team_membership" "opsteam_members" {
  for_each = local.admins
  team_id  = github_team.opsteam.id
  username = each.value
  role     = "maintainer"
}

output "team_name" {
  value = github_team.opsteam.name
}
