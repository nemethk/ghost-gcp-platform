locals {
  # Every API the rest of the pipeline needs enabled, across both projects.
  required_services = [
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com",
    "secretmanager.googleapis.com",
    "storage.googleapis.com",
  ]
}

module "nonprod" {
  source        = "../../modules/fabric/modules/project"
  name          = var.nonprod_project_id
  project_reuse = { use_data_source = true }
  services      = local.required_services
}

module "production" {
  source        = "../../modules/fabric/modules/project"
  name          = var.production_project_id
  project_reuse = { use_data_source = true }
  services      = local.required_services
}
