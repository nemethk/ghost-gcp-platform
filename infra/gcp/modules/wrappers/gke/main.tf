# Thin wrapper around vendored fabric/modules/gke-cluster-autopilot
# (infra/gcp/modules/vendir.yml). Stages call this module, never fabric/
# directly.

module "cluster" {
  source              = "../../fabric/modules/gke-cluster-autopilot"
  project_id          = var.project_id
  name                = var.name
  location            = var.location
  release_channel     = var.release_channel
  deletion_protection = var.deletion_protection

  vpc_config = {
    network    = var.network_self_link
    subnetwork = var.subnet_self_link
    secondary_range_names = {
      pods     = var.pods_range_name
      services = var.services_range_name
    }
  }

  access_config = {
    private_nodes = true
    ip_access = {
      authorized_ranges = var.master_authorized_ranges
    }
  }
}
