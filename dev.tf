module "dev_cdn" {
  source             = "./hosting"
  subdomain          = "terraform-dev"
  cloudflare_zone_id = var.cloudflare_zone_id
}