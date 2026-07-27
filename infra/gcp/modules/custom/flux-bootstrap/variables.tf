variable "environment" {
  description = "Environment name (\"test\", \"acceptance\", \"production\") — selects gitops/clusters/<environment> and names the GitRepository/Kustomization."
  type        = string
  validation {
    condition     = contains(["test", "acceptance", "production"], var.environment)
    error_message = "Must be one of: test, acceptance, production."
  }
}

variable "github_owner" {
  description = "GitHub org/user that owns the repo."
  type        = string
}

variable "github_repo" {
  description = "GitHub repo name."
  type        = string
}

variable "git_branch" {
  description = "Branch Flux syncs from."
  type        = string
  default     = "main"
}

variable "chart_version" {
  description = "flux2 Helm chart version to pin."
  type        = string
}

variable "sops_age_private_key" {
  description = "age private key content for the sops-age Secret kustomize-controller uses to decrypt SOPS secrets. Sourced from Secret Manager by the calling stage — never committed as a tfvar."
  type        = string
  sensitive   = true
}
