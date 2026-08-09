output "project_id" {
  description = "GCP project that owns the homelab's external resources."
  value       = google_project.lab.project_id
}

output "project_number" {
  description = "Numeric project number (some IAM bindings and APIs want this rather than the ID)."
  value       = google_project.lab.number
}

output "tfstate_bucket" {
  description = "Name of the GCS bucket holding Terraform state for the homelab's TF roots."
  value       = google_storage_bucket.tfstate.name
}

output "talos_cluster_secrets_id" {
  description = "GSM secret ID holding talos/_out/secrets.yaml backups. Versions are uploaded out of band; see talos/README.md."
  value       = google_secret_manager_secret.talos_cluster_secrets.secret_id
}

output "ci_workload_identity_provider" {
  description = "Full resource name of the GitHub OIDC Workload Identity Provider. Set this as the GCP_WIF_PROVIDER repository variable in GitHub Actions."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "ci_service_account_email" {
  description = "Email of the plan-only CI service account. Set this as the GCP_CI_SA repository variable in GitHub Actions."
  value       = google_service_account.tf_ci.email
}

output "ci_apply_service_account_email" {
  description = "Email of the apply CI service account (roles/owner, env-scoped WIF). Set this as the GCP_APPLY_SA repository variable in GitHub Actions."
  value       = google_service_account.tf_ci_apply.email
}
