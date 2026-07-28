output "instances" {
  description = "Per-environment Cloud SQL connection info and the Secret Manager secret holding the Ghost DB user's password (never the password value itself)."
  value = {
    for env, inst in module.instance : env => {
      instance_name      = inst.instance_name
      private_ip_address = inst.private_ip_address
      database_name      = inst.database_name
      user_name          = inst.user_name
      password_secret_id = google_secret_manager_secret.db_password[env].secret_id
    }
  }
}

output "ghost_gsa_emails" {
  description = "Ghost's per-environment GCP service account email — goes into gitops/apps/gke/<env>/ghost-values.yaml's serviceAccount.gcpServiceAccountEmail, replacing the GCP_PROJECT_ID_PLACEHOLDER value committed there."
  value       = { for env, sa in module.ghost_gsa : env => sa.email }
}
