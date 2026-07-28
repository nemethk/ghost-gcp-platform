terraform {
  backend "gcs" {
    bucket = "ghost-gcp-platform-tfstate"
    prefix = "5-databases"
  }
}
