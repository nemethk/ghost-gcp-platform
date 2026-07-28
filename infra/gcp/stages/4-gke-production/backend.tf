terraform {
  backend "gcs" {
    bucket = "ghost-gcp-platform-tfstate"
    prefix = "4-gke-production"
  }
}
