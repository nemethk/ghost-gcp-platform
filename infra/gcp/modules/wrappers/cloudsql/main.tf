# Thin wrapper around vendored fabric/modules/cloudsql-instance
# (infra/gcp/modules/vendir.yml). Stages call this module, never fabric/
# directly. Private connectivity only — no public IP — via the PSA range
# reserved by infra/gcp/modules/wrappers/networking.

module "instance" {
  source            = "../../fabric/modules/cloudsql-instance"
  project_id        = var.project_id
  name              = var.name
  region            = var.region
  database_version  = "MYSQL_8_0"
  tier              = var.tier
  availability_type = var.availability_type
  disk_size         = var.disk_size

  gcp_deletion_protection       = var.deletion_protection
  terraform_deletion_protection = var.deletion_protection

  network_config = {
    connectivity = {
      public_ipv4 = false
      psa_config = {
        private_network = var.network_self_link
      }
    }
  }

  backup_configuration = {
    enabled            = var.backup_enabled
    binary_log_enabled = var.backup_enabled
  }

  databases = [var.database_name]

  users = {
    (var.user_name) = {
      password = var.user_password
      type     = "BUILT_IN"
    }
  }
}
