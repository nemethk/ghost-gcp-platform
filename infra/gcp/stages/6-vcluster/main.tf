data "terraform_remote_state" "gke_nonprod" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "4-gke-nonprod"
  }
}

data "google_client_config" "default" {}

module "test" {
  source        = "../../modules/custom/vcluster"
  name          = "test"
  chart_version = var.chart_version
}

module "acceptance" {
  source        = "../../modules/custom/vcluster"
  name          = "acceptance"
  chart_version = var.chart_version
}
