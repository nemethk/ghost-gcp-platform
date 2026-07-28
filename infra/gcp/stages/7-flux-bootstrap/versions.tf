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
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.31.0, < 3.0.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0.0, < 3.0.0"
    }
  }
}

# Reads the vCluster kubeconfig Secrets off the host (nonprod) cluster —
# the `google` provider from the fetched provider.tf authenticates this one
# via the impersonated SA + Workload Identity, same as every other stage.
provider "kubernetes" {
  alias                  = "host"
  host                   = "https://${data.terraform_remote_state.gke_nonprod.outputs.endpoint}"
  cluster_ca_certificate = base64decode(data.terraform_remote_state.gke_nonprod.outputs.ca_certificate)
  token                  = data.google_client_config.default.access_token
}

# Test and Acceptance: vCluster's own virtual API server, reached with the
# client-certificate credentials from its generated kubeconfig. Real caveat:
# vCluster's default kubeconfig points at an in-cluster service DNS name —
# reachable from Cloud Build only via a private worker pool peered into the
# VPC, or by giving the vCluster Service an externally-reachable endpoint.
# Not resolved here; this stage is code-only, not applied.
provider "helm" {
  alias = "test"
  kubernetes {
    host                   = local.vcluster_kubeconfig["test"].clusters[0].cluster.server
    cluster_ca_certificate = base64decode(local.vcluster_kubeconfig["test"].clusters[0].cluster["certificate-authority-data"])
    client_certificate     = base64decode(local.vcluster_kubeconfig["test"].users[0].user["client-certificate-data"])
    client_key             = base64decode(local.vcluster_kubeconfig["test"].users[0].user["client-key-data"])
  }
}

provider "kubernetes" {
  alias                  = "test"
  host                   = local.vcluster_kubeconfig["test"].clusters[0].cluster.server
  cluster_ca_certificate = base64decode(local.vcluster_kubeconfig["test"].clusters[0].cluster["certificate-authority-data"])
  client_certificate     = base64decode(local.vcluster_kubeconfig["test"].users[0].user["client-certificate-data"])
  client_key             = base64decode(local.vcluster_kubeconfig["test"].users[0].user["client-key-data"])
}

provider "kubectl" {
  alias                  = "test"
  host                   = local.vcluster_kubeconfig["test"].clusters[0].cluster.server
  cluster_ca_certificate = base64decode(local.vcluster_kubeconfig["test"].clusters[0].cluster["certificate-authority-data"])
  client_certificate     = base64decode(local.vcluster_kubeconfig["test"].users[0].user["client-certificate-data"])
  client_key             = base64decode(local.vcluster_kubeconfig["test"].users[0].user["client-key-data"])
  load_config_file       = false
}

provider "helm" {
  alias = "acceptance"
  kubernetes {
    host                   = local.vcluster_kubeconfig["acceptance"].clusters[0].cluster.server
    cluster_ca_certificate = base64decode(local.vcluster_kubeconfig["acceptance"].clusters[0].cluster["certificate-authority-data"])
    client_certificate     = base64decode(local.vcluster_kubeconfig["acceptance"].users[0].user["client-certificate-data"])
    client_key             = base64decode(local.vcluster_kubeconfig["acceptance"].users[0].user["client-key-data"])
  }
}

provider "kubernetes" {
  alias                  = "acceptance"
  host                   = local.vcluster_kubeconfig["acceptance"].clusters[0].cluster.server
  cluster_ca_certificate = base64decode(local.vcluster_kubeconfig["acceptance"].clusters[0].cluster["certificate-authority-data"])
  client_certificate     = base64decode(local.vcluster_kubeconfig["acceptance"].users[0].user["client-certificate-data"])
  client_key             = base64decode(local.vcluster_kubeconfig["acceptance"].users[0].user["client-key-data"])
}

provider "kubectl" {
  alias                  = "acceptance"
  host                   = local.vcluster_kubeconfig["acceptance"].clusters[0].cluster.server
  cluster_ca_certificate = base64decode(local.vcluster_kubeconfig["acceptance"].clusters[0].cluster["certificate-authority-data"])
  client_certificate     = base64decode(local.vcluster_kubeconfig["acceptance"].users[0].user["client-certificate-data"])
  client_key             = base64decode(local.vcluster_kubeconfig["acceptance"].users[0].user["client-key-data"])
  load_config_file       = false
}

# Production: a plain GKE cluster, no vCluster layer — same
# impersonated-token pattern as 6-vcluster used for the host cluster.
provider "helm" {
  alias = "production"
  kubernetes {
    host                   = "https://${data.terraform_remote_state.gke_production.outputs.endpoint}"
    cluster_ca_certificate = base64decode(data.terraform_remote_state.gke_production.outputs.ca_certificate)
    token                  = data.google_client_config.default.access_token
  }
}

provider "kubernetes" {
  alias                  = "production"
  host                   = "https://${data.terraform_remote_state.gke_production.outputs.endpoint}"
  cluster_ca_certificate = base64decode(data.terraform_remote_state.gke_production.outputs.ca_certificate)
  token                  = data.google_client_config.default.access_token
}

provider "kubectl" {
  alias                  = "production"
  host                   = "https://${data.terraform_remote_state.gke_production.outputs.endpoint}"
  cluster_ca_certificate = base64decode(data.terraform_remote_state.gke_production.outputs.ca_certificate)
  token                  = data.google_client_config.default.access_token
  load_config_file       = false
}
