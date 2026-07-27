# No provider blocks here on purpose — helm/kubectl must be configured in
# the calling stage (pointed at the target cluster: a vCluster context for
# Test/Acceptance, 4-gke-production directly for Production) and inherited
# by this module.

terraform {
  required_version = ">= 1.12.2"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.13.0, < 3.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.31.0, < 3.0.0"
    }
    # kubernetes_manifest needs the CRD known at plan time, which the
    # flux2 chart's own CRDs (installed by helm_release.flux2 in this same
    # apply) can't satisfy. kubectl_manifest applies raw YAML server-side
    # instead, sidestepping that chicken-and-egg — the standard workaround
    # for "Helm-installed CRD, Terraform-managed CR in the same apply".
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0.0, < 3.0.0"
    }
  }
}
