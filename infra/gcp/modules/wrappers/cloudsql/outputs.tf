output "instance_name" {
  description = "Name of the Cloud SQL instance."
  value       = module.instance.name
}

output "connection_name" {
  description = "Connection name, for the Cloud SQL Auth Proxy / connector-based access."
  value       = module.instance.connection_name
}

output "private_ip_address" {
  description = "Private IP address Ghost connects to."
  value       = module.instance.ip
}

output "database_name" {
  description = "Name of the Ghost database."
  value       = var.database_name
}

output "user_name" {
  description = "Name of the Ghost database user."
  value       = var.user_name
}
