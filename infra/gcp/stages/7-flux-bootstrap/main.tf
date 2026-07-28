data "terraform_remote_state" "gke_nonprod" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "4-gke-nonprod"
  }
}

data "terraform_remote_state" "gke_production" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "4-gke-production"
  }
}

data "terraform_remote_state" "vcluster" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "6-vcluster"
  }
}

data "google_client_config" "default" {}

# vCluster's own kubeconfig, read as a Secret from the host (nonprod)
# cluster — client-certificate auth, as vCluster generates it by default.
data "kubernetes_secret" "vcluster" {
  for_each = toset(["test", "acceptance"])
  provider = kubernetes.host
  metadata {
    name      = data.terraform_remote_state.vcluster.outputs[each.key].kubeconfig_secret_name
    namespace = data.terraform_remote_state.vcluster.outputs[each.key].namespace
  }
}

locals {
  vcluster_kubeconfig = {
    for env, secret in data.kubernetes_secret.vcluster :
    env => yamldecode(secret.data["config"])
  }
}

module "test" {
  source               = "../../modules/custom/flux-bootstrap"
  providers            = { helm = helm.test, kubernetes = kubernetes.test, kubectl = kubectl.test }
  environment          = "test"
  github_owner         = var.github_owner
  github_repo          = var.github_name
  chart_version        = var.chart_version
  sops_age_private_key = var.sops_age_private_key
}

module "acceptance" {
  source               = "../../modules/custom/flux-bootstrap"
  providers            = { helm = helm.acceptance, kubernetes = kubernetes.acceptance, kubectl = kubectl.acceptance }
  environment          = "acceptance"
  github_owner         = var.github_owner
  github_repo          = var.github_name
  chart_version        = var.chart_version
  sops_age_private_key = var.sops_age_private_key
}

module "production" {
  source               = "../../modules/custom/flux-bootstrap"
  providers            = { helm = helm.production, kubernetes = kubernetes.production, kubectl = kubectl.production }
  environment          = "production"
  github_owner         = var.github_owner
  github_repo          = var.github_name
  chart_version        = var.chart_version
  sops_age_private_key = var.sops_age_private_key
}
