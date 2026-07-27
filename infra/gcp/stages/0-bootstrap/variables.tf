variable "nonprod_project_id" {
  description = "Existing GCP project that hosts automation (state/outputs buckets, Cloud Build, per-stage SAs) as well as the Test/Acceptance workloads. Given, not created here."
  type        = string
}

variable "production_project_id" {
  description = "Existing GCP project for the Production environment. Given, not created here."
  type        = string
}

variable "region" {
  description = "Region for the state/outputs buckets."
  type        = string
  default     = "europe-west1"
}
