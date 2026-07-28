terraform {
  backend "gcs" {
    bucket = "ghost-gcp-platform-tfstate"
    prefix = "2-projects"
  }
}
