data "github_organization" "org" {
  name = var.github_organization
}

locals {
  users = {
    for _, member in data.github_organization.org.users :
    member.login => member.login 
    if contains(var.roles, lower(member.role))
  }
}

resource "github_team" "the_team" {
  name        = var.github_team
  description = var.description
  privacy     = "closed"
}

resource "github_team_membership" "team_members" {
  for_each = local.users
  team_id  = github_team.the_team.id
  username = each.value
  role     = "maintainer"
}

output "team_name" {
  value = github_team.the_team.name
}
