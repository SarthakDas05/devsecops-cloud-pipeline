output "service_url" {
  value       = google_cloud_run_v2_service.app_service.uri
  description = "The publicly accessible HTTPS URL of the Google Cloud Run microservice."
}

output "artifact_registry_repository_url" {
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo.name}"
  description = "The Docker repository URL in Google Artifact Registry."
}

output "workload_identity_provider_name" {
  value       = google_iam_workload_identity_pool_provider.github_provider.name
  description = "The full Workload Identity Provider resource name to supply to GitHub Actions auth."
}

output "deployer_service_account_email" {
  value       = google_service_account.github_deployer.email
  description = "The Service Account email used by GitHub Actions CI/CD."
}

output "runtime_service_account_email" {
  value       = google_service_account.cloud_run_runtime.email
  description = "The Service Account email assumed by the Cloud Run instance at runtime."
}
