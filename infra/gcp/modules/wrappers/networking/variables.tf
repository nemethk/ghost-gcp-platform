variable "project_id" {
  description = "Project where the VPC and its subnet are created."
  type        = string
}

variable "name" {
  description = "Name prefix for the VPC, subnet, router and Cloud NAT."
  type        = string
}

variable "region" {
  description = "Region for the single subnet, router and Cloud NAT."
  type        = string
}

variable "subnet_cidr" {
  description = "Primary CIDR range for the GKE nodes subnet."
  type        = string
}

variable "pods_cidr" {
  description = "Secondary CIDR range for GKE pod IPs (VPC-native cluster)."
  type        = string
}

variable "services_cidr" {
  description = "Secondary CIDR range for GKE service IPs (VPC-native cluster)."
  type        = string
}

variable "psa_range_cidr" {
  description = "CIDR range reserved for Private Service Access, used for Cloud SQL private connectivity."
  type        = string
}

variable "nat_enabled" {
  description = "Create a Cloud Router + Cloud NAT for the subnet's region. Required when GKE nodes are private (no public IP)."
  type        = bool
  default     = true
}
