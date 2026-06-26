
# MX Records
locals {
  domains = [
    "doofnet.uk",
    "nikdoof.com",
    "nikdoof.id",
    "intellectops.com",
    "incognitus.net",
  ]
}

resource "digitalocean_record" "mx" {
  for_each = toset(local.domains)
  domain   = each.value
  type     = "MX"
  name     = "@"
  value    = "mx-01.doofnet.uk."
  priority = 0
  ttl      = 3600
}

resource "digitalocean_record" "mx_imaps" {
  for_each = toset(local.domains)
  domain   = each.value
  type     = "SRV"
  name     = "_imaps._tcp"
  value    = "mx-01.doofnet.uk."
  priority = 0
  weight   = 1
  port     = 993
  ttl      = 3600
}

resource "digitalocean_record" "mx_submission" {
  for_each = toset(local.domains)
  domain   = each.value
  type     = "SRV"
  name     = "_submission._tcp"
  value    = "mx-01.doofnet.uk."
  priority = 0
  weight   = 1
  port     = 587
  ttl      = 3600
}

resource "digitalocean_record" "spf" {
  for_each = toset(local.domains)
  domain   = each.value
  type     = "TXT"
  name     = "@"
  value    = "v=spf1 include:_spf.doofnet.uk mx -all"
  priority = 0
  ttl      = 3600
}

resource "digitalocean_record" "dmarc" {
  for_each = toset(local.domains)
  domain   = each.value
  type     = "TXT"
  name     = "_dmarc"
  value    = "v=DMARC1; p=quarantine; rua=mailto:dmarc-reports@doofnet.uk"
  priority = 0
  ttl      = 3600
}

resource "digitalocean_record" "dmarc_report" {
  for_each = toset(local.domains)
  domain   = "doofnet.uk"
  type     = "TXT"
  name     = "${each.value}._report._dmarc"
  value    = "v=DMARC1"
  priority = 0
  ttl      = 3600
}
