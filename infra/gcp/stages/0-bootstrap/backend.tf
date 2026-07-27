# Chicken-and-egg: this stage creates its own state bucket
# (module.state_bucket below), so it can't reference that bucket's name here
# — Terraform backend blocks only accept literal values, no interpolation.
# Bootstrap sequence: `terraform init -backend=false` → `apply` (creates the
# bucket) → `terraform init` again (migrates state into it) → `apply` again.
# One-time, manual — Cloud Build doesn't exist yet to run this for you.
terraform {
  backend "gcs" {
    bucket = "ghost-gcp-platform-tfstate"
    prefix = "0-bootstrap"
  }
}
