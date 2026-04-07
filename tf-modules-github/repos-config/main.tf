data "github_organization" "org" {
  name = var.github_organization
}

locals {
  all_repo_names = [
    for r in data.github_organization.org.repositories :
    split("/", r)[1]
  ]

  repo_names = [for repo in local.all_repo_names : repo if !(contains(var.ignored_repos, repo))]

  repo_secret_pairs = merge([
    for repo in local.repo_names : {
      for secret_name, secret_value in var.repo_secrets : "${repo}__${secret_name}" => {
        repository      = repo
        secret_name     = secret_name
      }
    }
  ]...)

  repo_variable_pairs = merge([
    for repo in local.repo_names : {
      for variable_name, variable_value in var.repo_variables : "${repo}__${variable_name}" => {
        repository      = repo
        variable_name   = variable_name
      }
    }
  ]...)
}

resource "github_actions_secret" "repo_secret" {
  for_each = local.repo_secret_pairs

  repository      = each.value.repository
  secret_name     = each.value.secret_name
  plaintext_value = var.repo_secrets[each.value.secret_name] 
}

resource "github_actions_variable" "repo_variable" {
  for_each = local.repo_variable_pairs

  repository    = each.value.repository
  variable_name = each.value.variable_name
  value         = var.repo_variables[each.value.variable_name] 
}

output "repositories" {
  value = local.repo_names
}
