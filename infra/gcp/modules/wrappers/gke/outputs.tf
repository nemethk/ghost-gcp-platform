output "name" {
  description = "Cluster name."
  value       = module.cluster.name
}

output "endpoint" {
  description = "Cluster control-plane endpoint."
  value       = module.cluster.endpoint
}

output "ca_certificate" {
  description = "Public certificate of the cluster (base64-encoded)."
  value       = module.cluster.ca_certificate
  sensitive   = true
}

output "location" {
  description = "Cluster location."
  value       = module.cluster.location
}

output "self_link" {
  description = "Cluster self link."
  value       = module.cluster.self_link
  sensitive   = true
}

output "workload_identity_pool" {
  description = "Workload identity pool, for binding Kubernetes service accounts to GCP service accounts."
  value       = module.cluster.workload_identity_pool
}
