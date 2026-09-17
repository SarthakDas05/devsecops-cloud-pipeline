output "service_url" {
  value       = google_cloud_run_v2_service.app_service.uri
  description = "The publicly accessible HTTPS URL of the Google Cloud Run microservice."
}

output "artifact_registry_repository_url" {
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${data.google_artifact_registry_repository.docker_repo.repository_id}"
  description = "The Docker repository URL in Google Artifact Registry."
}

output "runtime_service_account_email" {
  value       = google_service_account.cloud_run_runtime.email
  description = "The Service Account email assumed by the Cloud Run instance at runtime."
}
