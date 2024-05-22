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

output "team_name" {
  value = github_team.opsteam.name
}
