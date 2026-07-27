locals {
  modified_working_directory = substr(var.working_directory, 2, length(var.working_directory))
  service_account            = "projects/${var.project}/serviceAccounts/${var.sa}"
}

# resource "random_id" "bucket_suffix" {
#   byte_length = 2
# }

# resource "google_storage_bucket" "gcs-bucket-tf-plans" {
#   name          = "${var.bucket_name_prefix}-${var.trigger_name_suffix}-${random_id.bucket_suffix.hex}"
#   location      = var.storage_location
#   force_destroy = true
#   project       = var.project

#   lifecycle_rule {
#     condition {
#       age = 30
#     }
#     action {
#       type = "Delete"
#     }
#   }
#   # retention_policy {
#   #   retention_period = var.plan_retention_days * 24 * 60 * 60
#   # }
# }

resource "google_cloudbuild_trigger" "tf-plan-trigger" {
  project         = var.project
  location        = var.region
  name            = "${var.prefix}-${var.short_region}-${var.trigger_name_suffix}plan-01"
  service_account = local.service_account

  github {
    owner = var.github_owner
    name  = var.github_name
    push {
      branch = var.branches_to_plan_regex
    }
  }

  disabled = false

  substitutions = {
    _INCLUDE_BUILD_ID         = var.include_build_id
    _GCS_TF_STATE_BUCKET_NAME = var.tfstate_gcs_bucket
    _GCS_OUTPUTS_BUCKET_NAME  = var.outputs_gcs_bucket
  }

  included_files = ["${local.modified_working_directory}**", "infra/gcp/modules/**"]

  build {
    options {
      logging = "CLOUD_LOGGING_ONLY"
    }
    step {
      name       = "gcr.io/cloud-builders/gsutil"
      id         = "fetch-provider"
      dir        = var.working_directory
      entrypoint = "bash"
      args       = ["-c", "source <(../../stage-links.sh gs://$_GCS_OUTPUTS_BUCKET_NAME)"]
    }
    step {
      name = var.terraform_image
      id   = "init"
      dir  = var.working_directory
      args = ["init"]
    }
    step {
      name = var.terraform_image
      id   = "plan"
      dir  = var.working_directory
      args = ["plan", "-out", "./$COMMIT_SHA"]
    }
    step {
      name       = "gcr.io/cloud-builders/gsutil"
      id         = "load-plan"
      dir        = var.working_directory
      entrypoint = "bash"
      args = ["-c", <<EOT
        if [ $_INCLUDE_BUILD_ID == false ]
        then
          gsutil cp ./$_WORKING_DIRECTORY/$COMMIT_SHA gs://$_GCS_TF_STATE_BUCKET_NAME
        else
          mv ./$_WORKING_DIRECTORY/$COMMIT_SHA ./$_WORKING_DIRECTORY/$COMMIT_SHA-$BUILD_ID &&
          gsutil cp ./$_WORKING_DIRECTORY/$COMMIT_SHA-$BUILD_ID gs://$_GCS_TF_STATE_BUCKET_NAME
        fi
EOT
      ]
    }
  }
}

resource "google_cloudbuild_trigger" "tf-apply-trigger" {
  project         = var.project
  location        = var.region
  name            = "${var.prefix}-${var.short_region}-${var.trigger_name_suffix}apply-01"
  service_account = local.service_account

  github {
    owner = var.github_owner
    name  = var.github_name
    push {
      branch = var.branches_to_apply_regex
    }
  }
  disabled = var.apply_disabled

  substitutions = {
    _INCLUDE_BUILD_ID         = var.include_build_id
    _BUILD_ID                 = 0
    _GCS_TF_STATE_BUCKET_NAME = var.tfstate_gcs_bucket
    _GCS_OUTPUTS_BUCKET_NAME  = var.outputs_gcs_bucket
  }

  build {
    options {
      logging = "CLOUD_LOGGING_ONLY"
    }
    step {
      name       = "gcr.io/cloud-builders/gsutil"
      id         = "fetch-provider"
      dir        = var.working_directory
      entrypoint = "bash"
      args       = ["-c", "source <(../../stage-links.sh gs://$_GCS_OUTPUTS_BUCKET_NAME)"]
    }
    step {
      name = var.terraform_image
      id   = "init"
      dir  = var.working_directory
      args = ["init"]
    }
    step {
      name       = "gcr.io/cloud-builders/gsutil"
      id         = "load-plan"
      dir        = var.working_directory
      entrypoint = "bash"
      args = ["-c", <<EOT
        if [ $_INCLUDE_BUILD_ID == false ]
        then
          gsutil cp gs://$_GCS_TF_STATE_BUCKET_NAME/$COMMIT_SHA ./plan
        else
          gsutil cp gs://$_GCS_TF_STATE_BUCKET_NAME/$COMMIT_SHA-$_BUILD_ID ./plan
        fi
EOT
      ]
    }
    step {
      name = var.terraform_image
      id   = "apply"
      dir  = var.working_directory
      args = ["apply", "plan"]
    }
    timeout = "1800s"
  }

  approval_config {
    approval_required = true
  }

}
