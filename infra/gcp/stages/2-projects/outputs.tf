# Read by downstream stages via `data "terraform_remote_state"` (bucket =
# var.state_bucket, prefix = "2-projects"), not via stage-links.sh tfvars.

output "nonprod_project_number" {
  value = module.nonprod.number
}

output "production_project_number" {
  value = module.production.number
}
