data "terraform_remote_state" "networking" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "3-networking"
  }
}

module "cluster" {
  source                   = "../../modules/wrappers/gke"
  project_id               = var.nonprod_project_id
  name                     = "ghost-nonprod"
  location                 = data.terraform_remote_state.networking.outputs.nonprod.region
  network_self_link        = data.terraform_remote_state.networking.outputs.nonprod.network_self_link
  subnet_self_link         = data.terraform_remote_state.networking.outputs.nonprod.subnet_self_link
  pods_range_name          = data.terraform_remote_state.networking.outputs.nonprod.pods_range_name
  services_range_name      = data.terraform_remote_state.networking.outputs.nonprod.services_range_name
  master_authorized_ranges = var.master_authorized_ranges

  # Test/Acceptance share this cluster and iterate fast — easy teardown
  # matters more here than on the dedicated production cluster.
  deletion_protection = false
}
