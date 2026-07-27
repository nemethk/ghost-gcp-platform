locals {
  namespace = coalesce(var.namespace, "vcluster-${var.name}")
}

resource "helm_release" "vcluster" {
  name             = var.name
  namespace        = local.namespace
  create_namespace = true
  repository       = "https://charts.loft.sh"
  chart            = "vcluster"
  version          = var.chart_version

  values = [yamlencode({
    controlPlane = {
      statefulSet = {
        resources = {
          requests = var.resources.requests
          limits   = var.resources.limits
        }
      }
    }
    # Test and Acceptance stay unreachable from each other and from the host
    # cluster's own workloads — real isolation at the vCluster/RBAC layer,
    # not the GCP-project layer.
    sync = {
      toHost = {
        ingresses = { enabled = false }
      }
    }
  })]
}
