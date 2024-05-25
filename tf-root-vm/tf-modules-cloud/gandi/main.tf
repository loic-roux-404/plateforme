data "gandi_domain" "k3s_domain" {
  name = var.paas_base_domain
}

resource "gandi_livedns_record" "www" {
  for_each = toset(["@", "*"])
  zone     = data.gandi_domain.k3s_domain.id
  name     = each.key
  type     = "A"
  ttl      = 3600
  values = [var.target_ip]
}
