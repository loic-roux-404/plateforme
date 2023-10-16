resource "waypoint_auth_method_oidc" "dex" {
  name          = "dex-oidc"
  display_name = "Dex OIDC"
  client_id     = var.dex_client_id
  client_secret = var.dex_client_secret
  discovery_url = "${var.dex_hostname}"
  allowed_redirect_urls = [
    "https://${var.paas_hostname}/auth/oidc-callback",
  ]

  accessor_selector = "${var.dex_github_client_org}:${var.dex_github_client_team}"

  list_claim_mappings = {
    groups = "groups"
  }

  signing_algs = [
    "rsa512"
  ]
}
