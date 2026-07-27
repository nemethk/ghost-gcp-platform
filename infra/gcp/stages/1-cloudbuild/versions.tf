terraform {
  required_version = ">= 1.12.2"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.40.0, < 8.0.0"
    }
  }
}

# provider.tf, generated from 0-bootstrap's template and fetched via
# ../../stage-links.sh, supplies the actual impersonating provider block —
# this file only pins versions.
