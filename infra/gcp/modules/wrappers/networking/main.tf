# Thin wrapper around vendored fabric/modules/{net-vpc,net-vpc-firewall,net-cloudnat}
# (infra/gcp/modules/vendir.yml). Environment roots call this module, never
# fabric/ directly.

locals {
  pods_range_name     = "pods"
  services_range_name = "services"
}

module "vpc" {
  source     = "../../fabric/modules/net-vpc"
  project_id = var.project_id
  name       = var.name

  subnets = [
    {
      name          = "${var.name}-nodes"
      region        = var.region
      ip_cidr_range = var.subnet_cidr
      secondary_ip_ranges = {
        (local.pods_range_name)     = { ip_cidr_range = var.pods_cidr }
        (local.services_range_name) = { ip_cidr_range = var.services_cidr }
      }
    }
  ]

  psa_configs = [
    {
      ranges = { (var.name) = var.psa_range_cidr }
    }
  ]
}

module "firewall" {
  source     = "../../fabric/modules/net-vpc-firewall"
  project_id = var.project_id
  network    = module.vpc.name
}

module "nat" {
  source         = "../../fabric/modules/net-cloudnat"
  count          = var.nat_enabled ? 1 : 0
  project_id     = var.project_id
  name           = "${var.name}-nat"
  region         = var.region
  router_create  = true
  router_network = module.vpc.name
}
