terraform {
  required_version = ">= 1.12.2"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.40.0, < 8.0.0"
    }
  }
}

# Applied with the operator's own credentials (`gcloud auth
# application-default login`) — no impersonation. Every downstream stage
# impersonates a least-privilege SA created here instead of using a human's
# credentials directly.
provider "google" {
  region = var.region
}
