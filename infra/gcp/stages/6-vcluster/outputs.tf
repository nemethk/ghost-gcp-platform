# Read by 7-flux-bootstrap via `data "terraform_remote_state"`
# (bucket = var.state_bucket, prefix = "6-vcluster").

output "test" {
  value = {
    namespace              = module.test.namespace
    kubeconfig_secret_name = module.test.kubeconfig_secret_name
  }
}

output "acceptance" {
  value = {
    namespace              = module.acceptance.namespace
    kubeconfig_secret_name = module.acceptance.kubeconfig_secret_name
  }
}
