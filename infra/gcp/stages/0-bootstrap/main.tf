locals {
  # One least-privilege automation SA per downstream stage, all living in
  # the nonprod project (the "automation home"). Roles are scoped per stage:
  # container.admin, cloudsql.admin, compute.networkAdmin — never
  # owner/editor.
  stage_sas = {
    "1-cloudbuild" = {
      display_name = "Terraform 1-cloudbuild — creates the plan/apply triggers for every other stage."
      iam_project_roles = {
        (var.nonprod_project_id) = ["roles/cloudbuild.builds.editor", "roles/storage.admin"]
      }
    }
    "2-projects" = {
      display_name = "Terraform 2-projects — adopts the two existing projects, enables APIs."
      iam_project_roles = {
        (var.nonprod_project_id)    = ["roles/resourcemanager.projectIamAdmin", "roles/serviceusage.serviceUsageAdmin"]
        (var.production_project_id) = ["roles/resourcemanager.projectIamAdmin", "roles/serviceusage.serviceUsageAdmin"]
      }
    }
    "3-networking" = {
      display_name = "Terraform 3-networking — VPCs, subnets, PSA, Cloud NAT."
      iam_project_roles = {
        (var.nonprod_project_id)    = ["roles/compute.networkAdmin"]
        (var.production_project_id) = ["roles/compute.networkAdmin"]
      }
    }
    "4-gke-nonprod" = {
      display_name = "Terraform 4-gke-nonprod — shared GKE Autopilot cluster."
      iam_project_roles = {
        (var.nonprod_project_id) = ["roles/container.admin"]
      }
    }
    "4-gke-production" = {
      display_name = "Terraform 4-gke-production — dedicated GKE Autopilot cluster."
      iam_project_roles = {
        (var.production_project_id) = ["roles/container.admin"]
      }
    }
    "5-databases" = {
      display_name = "Terraform 5-databases — Cloud SQL: test, acceptance, production."
      iam_project_roles = {
        (var.nonprod_project_id)    = ["roles/cloudsql.admin"]
        (var.production_project_id) = ["roles/cloudsql.admin"]
      }
    }
    "6-vcluster" = {
      display_name = "Terraform 6-vcluster — installs vcluster onto 4-gke-nonprod."
      iam_project_roles = {
        (var.nonprod_project_id) = ["roles/container.developer"]
      }
    }
    "7-flux-bootstrap" = {
      display_name = "Terraform 7-flux-bootstrap — installs flux2 into every cluster."
      iam_project_roles = {
        (var.nonprod_project_id)    = ["roles/container.developer"]
        (var.production_project_id) = ["roles/container.developer"]
      }
    }
  }
}

module "state_bucket" {
  source        = "../../modules/fabric/modules/gcs"
  project_id    = var.nonprod_project_id
  name          = "ghost-gcp-platform-tfstate"
  location      = var.region
  versioning    = true
  force_destroy = false
}

module "outputs_bucket" {
  source        = "../../modules/fabric/modules/gcs"
  project_id    = var.nonprod_project_id
  name          = "ghost-gcp-platform-tfoutputs"
  location      = var.region
  versioning    = true
  force_destroy = false
}

module "stage_sa" {
  source            = "../../modules/fabric/modules/iam-service-account"
  for_each          = local.stage_sas
  project_id        = var.nonprod_project_id
  name              = "tf-${each.key}"
  display_name      = each.value.display_name
  iam_project_roles = each.value.iam_project_roles
  # 1-cloudbuild's own SA creates every stage's Cloud Build trigger and
  # attaches each stage's SA to its trigger
  # (google_cloudbuild_trigger.service_account) — that attachment needs
  # serviceAccountUser on the target, not tokenCreator, so grant both:
  # tokenCreator covers local/manual impersonation for testing, matching the
  # providers.tf.tpl pattern shared by every stage.
  iam = each.key == "1-cloudbuild" ? {} : {
    "roles/iam.serviceAccountTokenCreator" = [module.stage_sa["1-cloudbuild"].iam_email]
    "roles/iam.serviceAccountUser"         = [module.stage_sa["1-cloudbuild"].iam_email]
  }
}
