locals {
  # Public repo, read-only reconcile — no deploy key / secretRef needed here,
  # unlike the local demo's `flux bootstrap` CLI default (which also grants
  # write access it doesn't actually use on real GKE).
  git_url = "https://github.com/${var.github_owner}/${var.github_repo}"
}

resource "helm_release" "flux2" {
  name             = "flux2"
  namespace        = "flux-system"
  create_namespace = true
  repository       = "https://fluxcd-community.github.io/helm-charts"
  chart            = "flux2"
  version          = var.chart_version
}

resource "kubernetes_secret" "sops_age" {
  metadata {
    name      = "sops-age"
    namespace = "flux-system"
  }
  data = {
    "age.agekey" = var.sops_age_private_key
  }
  depends_on = [helm_release.flux2]
}

resource "kubectl_manifest" "git_repository" {
  yaml_body = yamlencode({
    apiVersion = "source.toolkit.fluxcd.io/v1"
    kind       = "GitRepository"
    metadata = {
      name      = "flux-system"
      namespace = "flux-system"
    }
    spec = {
      interval = "1m0s"
      ref      = { branch = var.git_branch }
      url      = local.git_url
    }
  })
  depends_on = [helm_release.flux2]
}

resource "kubectl_manifest" "kustomization" {
  yaml_body = yamlencode({
    apiVersion = "kustomize.toolkit.fluxcd.io/v1"
    kind       = "Kustomization"
    metadata = {
      name      = "flux-system"
      namespace = "flux-system"
    }
    spec = {
      interval = "10m0s"
      path     = "./gitops/clusters/${var.environment}"
      prune    = true
      sourceRef = {
        kind = "GitRepository"
        name = "flux-system"
      }
    }
  })
  depends_on = [kubectl_manifest.git_repository, kubernetes_secret.sops_age]
}
