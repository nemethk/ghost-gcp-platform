terraform {
  backend "gcs" {
    bucket = "ghost-gcp-platform-tfstate"
    prefix = "6-vcluster"
  }
}
