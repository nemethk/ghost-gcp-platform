# No provider block here on purpose — the `helm` provider must be configured
# in the calling stage (pointed at the 4-gke-nonprod cluster) and inherited
# by this module. A child module configuring its own provider is a
# Terraform anti-pattern (blocks passing multiple aliased instances of this
# module for multiple clusters later).

terraform {
  required_version = ">= 1.12.2"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.13.0, < 3.0.0"
    }
  }
}
