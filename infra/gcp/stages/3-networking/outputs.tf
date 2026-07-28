# Read by downstream stages via `data "terraform_remote_state"` (bucket =
# var.state_bucket, prefix = "3-networking"), not via stage-links.sh tfvars.

output "nonprod" {
  value = {
    network_self_link   = module.nonprod.network_self_link
    subnet_self_link    = module.nonprod.subnet_self_link
    pods_range_name     = module.nonprod.pods_range_name
    services_range_name = module.nonprod.services_range_name
    region              = module.nonprod.region
  }
}

output "production" {
  value = {
    network_self_link   = module.production.network_self_link
    subnet_self_link    = module.production.subnet_self_link
    pods_range_name     = module.production.pods_range_name
    services_range_name = module.production.services_range_name
    region              = module.production.region
  }
}

output "ghost_lb_ips" {
  description = "Reserved external IP per environment — goes into each gke/<env>/configs-kustomization.yaml's postBuild.substitute as GKE_STATIC_IP, and into the GoDaddy A record."
  value       = { for env, addr in google_compute_address.ghost_lb : env => addr.address }
}
