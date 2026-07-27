variable "project_id" {
  description = "Cluster project ID."
  type        = string
}

variable "name" {
  description = "Cluster name."
  type        = string
}

variable "location" {
  description = "Region for the cluster (Autopilot clusters are always regional)."
  type        = string
}

variable "network_self_link" {
  description = "Self link of the VPC to attach the cluster to (infra/gcp/modules/networking output)."
  type        = string
}

variable "subnet_self_link" {
  description = "Self link of the nodes subnet (infra/gcp/modules/networking output)."
  type        = string
}

variable "pods_range_name" {
  description = "Name of the subnet's secondary range for pod IPs (infra/gcp/modules/networking output)."
  type        = string
}

variable "services_range_name" {
  description = "Name of the subnet's secondary range for service IPs (infra/gcp/modules/networking output)."
  type        = string
}

variable "master_authorized_ranges" {
  description = "CIDR ranges allowed to reach the public control-plane endpoint, keyed by a description. No default — every stage must make an explicit choice instead of inheriting an open one."
  type        = map(string)
  nullable    = false
}

variable "release_channel" {
  description = "GKE release channel. Autopilot clusters must use one."
  type        = string
  default     = "REGULAR"
}

variable "deletion_protection" {
  description = "Block terraform destroy / an apply that would delete this cluster. Safe default is true; non-prod stages may override to false for easy teardown."
  type        = bool
  default     = true
}
