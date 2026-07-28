variable "nonprod_project_id" {
  description = "From 0-bootstrap's published tfvars."
  type        = string
}

variable "production_project_id" {
  description = "From 0-bootstrap's published tfvars."
  type        = string
}

variable "region" {
  description = "Region for both VPCs' subnets."
  type        = string
  default     = "europe-west1"
}

variable "nonprod_cidrs" {
  description = "CIDR ranges for the nonprod VPC (shared by Test + Acceptance vClusters)."
  type = object({
    subnet   = string
    pods     = string
    services = string
    psa      = string
  })
  default = {
    subnet   = "10.10.0.0/20"
    pods     = "10.20.0.0/14"
    services = "10.30.0.0/20"
    psa      = "10.40.0.0/16"
  }
}

variable "production_cidrs" {
  description = "CIDR ranges for the production VPC."
  type = object({
    subnet   = string
    pods     = string
    services = string
    psa      = string
  })
  default = {
    subnet   = "10.50.0.0/20"
    pods     = "10.60.0.0/14"
    services = "10.70.0.0/20"
    psa      = "10.80.0.0/16"
  }
}
