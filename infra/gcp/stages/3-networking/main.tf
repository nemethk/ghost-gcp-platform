module "nonprod" {
  source         = "../../modules/wrappers/networking"
  project_id     = var.nonprod_project_id
  name           = "ghost-nonprod"
  region         = var.region
  subnet_cidr    = var.nonprod_cidrs.subnet
  pods_cidr      = var.nonprod_cidrs.pods
  services_cidr  = var.nonprod_cidrs.services
  psa_range_cidr = var.nonprod_cidrs.psa
}

module "production" {
  source         = "../../modules/wrappers/networking"
  project_id     = var.production_project_id
  name           = "ghost-production"
  region         = var.region
  subnet_cidr    = var.production_cidrs.subnet
  pods_cidr      = var.production_cidrs.pods
  services_cidr  = var.production_cidrs.services
  psa_range_cidr = var.production_cidrs.psa
}

locals {
  # One reserved external IP per environment, not per project — Test and
  # Acceptance share the nonprod VPC but each still gets its own Envoy
  # Gateway LoadBalancer Service (they run inside separate vClusters), so
  # each needs its own address.
  environments = {
    test       = { project_id = var.nonprod_project_id }
    acceptance = { project_id = var.nonprod_project_id }
    production = { project_id = var.production_project_id }
  }
}

# Reserved, not ephemeral: an ephemeral GCP external IP is stable across
# routine changes but not guaranteed to survive the Service/Gateway being
# deleted and recreated — this makes the manually-managed GoDaddy A record
# actually trustworthy long-term, not just stable-in-practice.
resource "google_compute_address" "ghost_lb" {
  for_each     = local.environments
  project      = each.value.project_id
  name         = "ghost-${each.key}-lb"
  region       = var.region
  address_type = "EXTERNAL"
}
