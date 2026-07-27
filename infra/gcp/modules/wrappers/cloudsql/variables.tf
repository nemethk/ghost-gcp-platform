variable "project_id" {
  description = "Project where the instance is created."
  type        = string
}

variable "name" {
  description = "Name of the Cloud SQL instance."
  type        = string
}

variable "region" {
  description = "Region for the instance."
  type        = string
}

variable "network_self_link" {
  description = "Self link of the VPC with a PSA range reserved for Cloud SQL (infra/gcp/modules/networking output)."
  type        = string
}

variable "tier" {
  description = "Machine type for the instance."
  type        = string
}

variable "availability_type" {
  description = "ZONAL or REGIONAL. Production should use REGIONAL for HA."
  type        = string
  default     = "ZONAL"
}

variable "disk_size" {
  description = "Disk size in GB. Null enables autoresize."
  type        = number
  default     = null
}

variable "database_name" {
  description = "Name of the Ghost database to create."
  type        = string
  default     = "ghost"
}

variable "user_name" {
  description = "Name of the Ghost database user to create."
  type        = string
  default     = "ghost"
}

variable "user_password" {
  description = "Password for the Ghost database user."
  type        = string
  sensitive   = true
}

variable "backup_enabled" {
  description = "Enable automated backups. Production should keep this true; non-prod may disable for cost."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Block terraform destroy / an apply that would delete this instance, and Google's own deletion protection. Safe default is true; non-prod stages may override to false for easy teardown."
  type        = bool
  default     = true
}
