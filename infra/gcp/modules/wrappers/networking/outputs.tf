output "network_self_link" {
  description = "Self link of the created VPC."
  value       = module.vpc.self_link
}

output "network_name" {
  description = "Name of the created VPC."
  value       = module.vpc.name
}

output "subnet_self_link" {
  description = "Self link of the nodes subnet."
  value       = module.vpc.subnet_self_links["${var.region}/${var.name}-nodes"]
}

output "subnet_name" {
  description = "Name of the nodes subnet."
  value       = "${var.name}-nodes"
}

output "region" {
  description = "Region the subnet, router and Cloud NAT were created in."
  value       = var.region
}

output "pods_range_name" {
  description = "Name of the secondary range used for GKE pod IPs."
  value       = local.pods_range_name
}

output "services_range_name" {
  description = "Name of the secondary range used for GKE service IPs."
  value       = local.services_range_name
}
