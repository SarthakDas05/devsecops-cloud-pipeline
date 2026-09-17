provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Reference the Artifact Registry Docker Repository
data "google_artifact_registry_repository" "docker_repo" {
  location      = var.region
  repository_id = var.artifact_registry_name
}

# Runtime identity for Cloud Run
resource "google_service_account" "cloud_run_runtime" {
  account_id   = "sa-cloud-run-runtime"
  display_name = "Cloud Run Microservice Runtime Service Account"
  description  = "Least-privilege identity used by the Cloud Run instance at runtime"
}

locals {
  full_image_url = "${var.region}-docker.pkg.dev/${var.project_id}/${data.google_artifact_registry_repository.docker_repo.repository_id}/${var.service_name}:${var.image_tag}"
}

# ==============================================================================
# Google Cloud Run (v2 API) Microservice
# ==============================================================================
resource "google_cloud_run_v2_service" "app_service" {
  name     = var.service_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.cloud_run_runtime.email

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    containers {
      image = local.full_image_url

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1000m"
          memory = "512Mi"
        }
        cpu_idle = true
      }

      env {
        name  = "APP_ENV"
        value = "production"
      }

      env {
        name  = "APP_LOG_LEVEL"
        value = "INFO"
      }

      # Startup Probe (Verifies app is listening)
      startup_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        initial_delay_seconds = 0
        period_seconds        = 5
        failure_threshold     = 3
        timeout_seconds       = 3
      }

      # Liveness Probe (Monitors ongoing health)
      liveness_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        period_seconds    = 15
        failure_threshold = 3
        timeout_seconds   = 3
      }
    }
  }
}

# Public Ingress IAM Binding
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  count    = var.allow_unauthenticated ? 1 : 0
  name     = google_cloud_run_v2_service.app_service.name
  location = google_cloud_run_v2_service.app_service.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}
