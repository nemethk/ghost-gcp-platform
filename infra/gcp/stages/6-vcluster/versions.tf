terraform {
  required_version = ">= 1.12.2"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.40.0, < 8.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.13.0, < 3.0.0"
    }
  }
}

# The fetched provider.tf (../../stage-links.sh) supplies the impersonating
# `google` provider. This stage additionally needs `helm`, pointed at the
# 4-gke-nonprod cluster — that's stage-specific, so it's declared directly
# here rather than in the shared template.
provider "helm" {
  kubernetes {
    host                   = "https://${data.terraform_remote_state.gke_nonprod.outputs.endpoint}"
    cluster_ca_certificate = base64decode(data.terraform_remote_state.gke_nonprod.outputs.ca_certificate)
    token                  = data.google_client_config.default.access_token
  }
}
