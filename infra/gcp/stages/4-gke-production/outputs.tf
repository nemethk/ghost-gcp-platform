# Read by 7-flux-bootstrap via `data "terraform_remote_state"`
# (bucket = var.state_bucket, prefix = "4-gke-production").

output "name" {
  value = module.cluster.name
}

output "endpoint" {
  value = module.cluster.endpoint
}

output "ca_certificate" {
  value     = module.cluster.ca_certificate
  sensitive = true
}

output "location" {
  value = module.cluster.location
}
