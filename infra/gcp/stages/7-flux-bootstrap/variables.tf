variable "state_bucket" {
  description = "From 0-bootstrap's published tfvars — used to read 4-gke-nonprod's, 4-gke-production's and 6-vcluster's remote state."
  type        = string
}

variable "github_owner" {
  description = "GitHub org/user that owns the repo."
  type        = string
}

variable "github_name" {
  description = "GitHub repo name."
  type        = string
}

variable "chart_version" {
  description = "flux2 Helm chart version to pin, across all three targets."
  type        = string
}

variable "sops_age_private_key" {
  description = "age private key content for the sops-age Secret each cluster's kustomize-controller uses to decrypt SOPS secrets. Sourced from Secret Manager — never committed as a tfvar."
  type        = string
  sensitive   = true
}
