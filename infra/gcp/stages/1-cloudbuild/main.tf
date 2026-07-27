locals {
  # Auto-apply only for stages that touch nonprod exclusively. Anything that
  # touches production — even alongside nonprod in the same apply — keeps a
  # manual gate. 1-cloudbuild itself stays manual too: it configures the
  # delivery pipeline, so a bad change deserves a human look before it takes
  # effect.
  apply_disabled = {
    "1-cloudbuild"     = true
    "2-projects"       = true
    "3-networking"     = true
    "4-gke-nonprod"    = false
    "4-gke-production" = true
    "5-databases"      = true
    "6-vcluster"       = false
    "7-flux-bootstrap" = true
  }
}

module "plans_bucket" {
  source        = "../../modules/fabric/modules/gcs"
  project_id    = var.nonprod_project_id
  name          = "ghost-gcp-platform-tfplans"
  location      = var.region
  versioning    = false
  force_destroy = true
  lifecycle_rules = {
    expire-old-plans = {
      action    = { type = "Delete" }
      condition = { age = 30 }
    }
  }
}

module "trigger" {
  source              = "../../modules/custom/cloudbuild-triggers"
  for_each            = local.apply_disabled
  project             = var.nonprod_project_id
  region              = var.region
  github_owner        = var.github_owner
  github_name         = var.github_name
  working_directory   = "./infra/gcp/stages/${each.key}"
  trigger_name_suffix = "${each.key}-"
  sa                  = var.stage_service_accounts[each.key]
  terraform_image     = var.terraform_image
  tfstate_gcs_bucket  = module.plans_bucket.name
  outputs_gcs_bucket  = var.outputs_bucket
  apply_disabled      = each.value
}
