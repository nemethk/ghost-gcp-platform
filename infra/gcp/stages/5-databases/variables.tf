variable "nonprod_project_id" {
  description = "From 0-bootstrap's published tfvars."
  type        = string
}

variable "production_project_id" {
  description = "From 0-bootstrap's published tfvars."
  type        = string
}

variable "state_bucket" {
  description = "From 0-bootstrap's published tfvars — used to read 3-networking's remote state."
  type        = string
}

variable "ghost_ksa_name" {
  description = "Kubernetes ServiceAccount identity the Workload Identity binding is granted to, as <namespace>/<name>. Depends on Flux's Helm release-naming convention for the ghost HelmRelease (gitops/apps/base/ghost/release.yaml doesn't set spec.releaseName, so helm-controller picks the default) — verify this against the actual deployed ServiceAccount name (kubectl get sa -n ghost) before relying on it; not confirmed against a live cluster in this pass."
  type        = string
  default     = "ghost/ghost-ghost"
}
