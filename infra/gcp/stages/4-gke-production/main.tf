data "terraform_remote_state" "networking" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "3-networking"
  }
}

module "cluster" {
  source                   = "../../modules/wrappers/gke"
  project_id               = var.production_project_id
  name                     = "ghost-production"
  location                 = data.terraform_remote_state.networking.outputs.production.region
  network_self_link        = data.terraform_remote_state.networking.outputs.production.network_self_link
  subnet_self_link         = data.terraform_remote_state.networking.outputs.production.subnet_self_link
  pods_range_name          = data.terraform_remote_state.networking.outputs.production.pods_range_name
  services_range_name      = data.terraform_remote_state.networking.outputs.production.services_range_name
  master_authorized_ranges = var.master_authorized_ranges
  # deletion_protection defaults to true — the one cluster this repo should
  # never lose to a fat-fingered apply.
}
