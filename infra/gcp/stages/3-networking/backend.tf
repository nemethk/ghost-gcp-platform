terraform {
  backend "gcs" {
    bucket = "ghost-gcp-platform-tfstate"
    prefix = "3-networking"
  }
}
