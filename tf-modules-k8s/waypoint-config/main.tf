terraform {
  required_version = ">=1.4"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
  }
}

locals {
  oidc_setup_cmd = join(" ", [
    "waypoint auth-method set oidc",
    "-client-id='${var.dex_client_id}'",
    "-display-name='GitHub'",
    "-description='GitHub Oauth2 over Dex Idp open id connect adapter'",
    "-client-secret='${var.dex_client_secret}'",
    "-issuer=https://${var.dex_hostname}",
    "-allowed-redirect-uri='https://${var.paas_hostname}/auth/oidc-callback'",
    "-claim-scope='groups'",
    "-list-claim-mapping='groups=groups'",
    "-access-selector='\"${var.github_organization}:${var.github_team}\" in list.groups'",
    var.internal_acme_ca_content != null ? "-issuer-ca-pem='${var.internal_acme_ca_content}'" : "",
    "dex"
  ])

  login_cmd = join(" ", [
    "waypoint login",
    "-server-addr=${var.paas_hostname}:443",
    "-token=${var.paas_token}",
    "-server-tls-skip-verify=${var.tls_skip_verify}"
  ])
}

resource "terraform_data" "setup_oidc" {
  triggers_replace = {
    login_cmd      = local.login_cmd
    oidc_setup_cmd = local.oidc_setup_cmd
  }

  provisioner "local-exec" {
    command = local.login_cmd
  }

  provisioner "local-exec" {
    command = local.oidc_setup_cmd
  }
}
