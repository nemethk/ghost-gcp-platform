# Bucket name matches 0-bootstrap's module.state_bucket — literal because
# Terraform backend blocks don't accept interpolation. Everything after
# 0-bootstrap uses the same bucket with a per-stage prefix.
terraform {
  backend "gcs" {
    bucket = "ghost-gcp-platform-tfstate"
    prefix = "1-cloudbuild"
  }
}
