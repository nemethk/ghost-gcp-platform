variable "nonprod_project_id" {
  description = "From 0-bootstrap's published tfvars."
  type        = string
}

variable "state_bucket" {
  description = "From 0-bootstrap's published tfvars — used to read 3-networking's remote state."
  type        = string
}

variable "master_authorized_ranges" {
  description = "CIDR ranges allowed to reach the public control-plane endpoint, keyed by a description. No default — this stage must make an explicit choice."
  type        = map(string)
}
