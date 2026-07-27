output "name" {
  description = "vCluster / Helm release name."
  value       = helm_release.vcluster.name
}

output "namespace" {
  description = "Namespace on the host cluster the vCluster was installed into."
  value       = local.namespace
}

output "kubeconfig_secret_name" {
  description = "Name of the Secret vCluster writes its kubeconfig to, in `namespace` on the host cluster (consumed by 7-flux-bootstrap)."
  value       = "vc-${helm_release.vcluster.name}"
}
