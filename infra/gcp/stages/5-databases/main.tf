data "terraform_remote_state" "networking" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "3-networking"
  }
}

locals {
  # Cloud SQL is always one instance per environment — sharing GKE compute
  # in nonprod does not mean sharing a database. Test/Acceptance share the
  # nonprod VPC's PSA range; Production gets its own.
  environments = {
    test = {
      project_id          = var.nonprod_project_id
      network             = data.terraform_remote_state.networking.outputs.nonprod
      tier                = "db-custom-1-3840"
      availability_type   = "ZONAL"
      backup_enabled      = false
      deletion_protection = false
    }
    acceptance = {
      project_id          = var.nonprod_project_id
      network             = data.terraform_remote_state.networking.outputs.nonprod
      tier                = "db-custom-1-3840"
      availability_type   = "ZONAL"
      backup_enabled      = false
      deletion_protection = false
    }
    production = {
      project_id          = var.production_project_id
      network             = data.terraform_remote_state.networking.outputs.production
      tier                = "db-custom-2-7680"
      availability_type   = "REGIONAL"
      backup_enabled      = true
      deletion_protection = true
    }
  }
}

resource "random_password" "db" {
  for_each = local.environments
  length   = 24
  special  = false
}

resource "google_secret_manager_secret" "db_password" {
  for_each  = local.environments
  project   = each.value.project_id
  secret_id = "ghost-db-password-${each.key}"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  for_each    = local.environments
  secret      = google_secret_manager_secret.db_password[each.key].id
  secret_data = random_password.db[each.key].result
}

module "instance" {
  source              = "../../modules/wrappers/cloudsql"
  for_each            = local.environments
  project_id          = each.value.project_id
  name                = "ghost-${each.key}"
  region              = each.value.network.region
  network_self_link   = each.value.network.network_self_link
  tier                = each.value.tier
  availability_type   = each.value.availability_type
  backup_enabled      = each.value.backup_enabled
  deletion_protection = each.value.deletion_protection
  user_password       = random_password.db[each.key].result
}

# Ghost's own GCP identity — distinct from the Terraform automation SAs
# 0-bootstrap creates. One per environment, not shared: Test and Acceptance
# sit in the same nonprod project, and a shared GSA would let either read
# the other's database password, contradicting the unconditional
# per-environment data isolation the rest of this stage already assumes.
module "ghost_gsa" {
  source       = "../../modules/fabric/modules/iam-service-account"
  for_each     = local.environments
  project_id   = each.value.project_id
  name         = "ghost-${each.key}"
  display_name = "Ghost application identity (Workload Identity) — ${each.key}"
  # Binds the Kubernetes ServiceAccount to this GSA — Ghost's pod
  # authenticates as this identity with no key file mounted.
  iam = {
    "roles/iam.workloadIdentityUser" = [
      "serviceAccount:${each.value.project_id}.svc.id.goog[${var.ghost_ksa_name}]"
    ]
  }
}

# Scoped to the one secret this environment's Ghost actually needs — not
# granted at the project level, which in nonprod would leak Test's GSA
# access into Acceptance's secret and vice versa.
resource "google_secret_manager_secret_iam_member" "ghost_gsa_secret_access" {
  for_each  = local.environments
  project   = each.value.project_id
  secret_id = google_secret_manager_secret.db_password[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = module.ghost_gsa[each.key].iam_email
}
