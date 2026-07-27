# Publishes this stage's outputs to a GCS bucket every downstream stage
# fetches from via `../../stage-links.sh` — the Fabric FAST pattern.

locals {
  providers = {
    for stage, sa in module.stage_sa : stage => templatefile(
      "${path.module}/templates/providers.tf.tpl",
      {
        bucket = module.state_bucket.name
        name   = stage
        sa     = sa.email
      }
    )
  }
  tfvars = {
    nonprod_project_id     = var.nonprod_project_id
    production_project_id  = var.production_project_id
    state_bucket           = module.state_bucket.name
    outputs_bucket         = module.outputs_bucket.name
    stage_service_accounts = { for stage, sa in module.stage_sa : stage => sa.email }
  }
}

resource "google_storage_bucket_object" "providers" {
  for_each = local.providers
  bucket   = module.outputs_bucket.name
  name     = "providers/${each.key}-providers.tf"
  content  = each.value
}

resource "google_storage_bucket_object" "tfvars" {
  bucket  = module.outputs_bucket.name
  name    = "tfvars/0-bootstrap.auto.tfvars.json"
  content = jsonencode(local.tfvars)
}
