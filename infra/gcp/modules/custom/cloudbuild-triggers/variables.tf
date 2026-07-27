variable "include_build_id" {
  type        = bool
  description = "Switching this variable to true will require build id to apply a terraform plan"
  default     = false
}

variable "bucket_name_prefix" {
  type    = string
  default = "bucket-for-tf-plans"
}

variable "plan_retention_days" {
  type        = number
  description = "The number of days terraform plan files are kept in GCS"
  default     = 30
}

variable "storage_location" {
  type    = string
  default = "EU"
}

variable "project" {
  type = string
}

variable "region" {
  type    = string
  default = "europe-west1"
}

variable "short_region" {
  type    = string
  default = "ew1"
}

variable "prefix" {
  type    = string
  default = "cbld"
}

variable "github_owner" {
  type = string
}

variable "github_name" {
  type = string
}

variable "branches_to_plan_regex" {
  type    = string
  default = "main"
}

variable "branches_to_apply_regex" {
  type    = string
  default = "main"
}

variable "apply_disabled" {
  type        = bool
  description = "Whether the apply trigger starts disabled (manual \"run trigger\" required). Default true (safe/manual); set false for auto-apply on merge."
  default     = true
}

variable "working_directory" {
  type        = string
  description = "The path of the root terraform module inside the configured git repository"
  default     = "."
}

variable "trigger_name_suffix" {
  type        = string
  description = "Additional name suffix for multi-environment infrastructures"
  default     = "ops"
}

variable "terraform_image" {
  type = string
}

variable "sa" {
  type        = string
  description = "Service Account name"
}

variable "tfstate_gcs_bucket" {
  type        = string
  description = "GCS Buckets name for TF State"
}

variable "outputs_gcs_bucket" {
  type        = string
  description = "GCS Buckets for Outputs"
}