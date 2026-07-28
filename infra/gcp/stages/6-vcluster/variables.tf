variable "state_bucket" {
  description = "From 0-bootstrap's published tfvars — used to read 4-gke-nonprod's remote state."
  type        = string
}

variable "chart_version" {
  description = "vcluster Helm chart version to pin, for both Test and Acceptance."
  type        = string
}
