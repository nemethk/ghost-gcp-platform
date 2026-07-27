output "namespace" {
  description = "Namespace Flux was installed into."
  value       = "flux-system"
}

output "git_url" {
  description = "Repository URL the root GitRepository reconciles from."
  value       = local.git_url
}
