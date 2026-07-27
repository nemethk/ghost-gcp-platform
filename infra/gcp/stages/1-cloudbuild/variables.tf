variable "nonprod_project_id" {
  description = "From 0-bootstrap's published tfvars — triggers and the plan-artifacts bucket live here."
  type        = string
}

variable "production_project_id" {
  description = "From 0-bootstrap's published tfvars."
  type        = string
}

variable "state_bucket" {
  description = "Terraform state bucket, from 0-bootstrap's published tfvars."
  type        = string
}

variable "outputs_bucket" {
  description = "Outputs bucket stage-links.sh reads from, from 0-bootstrap's published tfvars."
  type        = string
}

variable "stage_service_accounts" {
  description = "Map of stage name => SA email, from 0-bootstrap's published tfvars. Each stage's trigger runs as its own SA."
  type        = map(string)
}

variable "github_owner" {
  description = "GitHub org/user that owns the repo."
  type        = string
}

variable "github_name" {
  description = "GitHub repo name."
  type        = string
}

variable "region" {
  description = "Region for the plan-artifacts bucket and trigger location."
  type        = string
  default     = "europe-west1"
}

variable "terraform_image" {
  description = "Container image each build step runs terraform in."
  type        = string
  default     = "hashicorp/terraform:1.12.2"
}
