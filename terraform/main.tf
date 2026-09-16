provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# ==============================================================================
# 1. Enable Required GCP APIs
# ==============================================================================
locals {
  required_services = [
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ]
}

resource "google_project_service" "enabled_apis" {
  for_each                   = toset(local.required_services)
  project                    = var.project_id
  service                    = each.value
  disable_dependent_services = false
  disable_on_destroy         = false
}

# ==============================================================================
# 2. Google Artifact Registry (Docker Repository)
# ==============================================================================
resource "google_artifact_registry_repository" "docker_repo" {
  provider      = google-beta
  location      = var.region
  repository_id = var.artifact_registry_name
  description   = "Docker repository for DevSecOps microservices"
  format        = "DOCKER"

  depends_on = [google_project_service.enabled_apis]
}

# ==============================================================================
# 3. Service Accounts (Least Privilege)
# ==============================================================================

# Runtime identity for Cloud Run
resource "google_service_account" "cloud_run_runtime" {
  account_id   = "sa-cloud-run-runtime"
  display_name = "Cloud Run Microservice Runtime Service Account"
  description  = "Least-privilege identity used by the Cloud Run instance at runtime"
}

# Deployer identity for GitHub Actions CI/CD
resource "google_service_account" "github_deployer" {
  account_id   = "sa-github-deployer"
  display_name = "GitHub Actions Deployer Service Account"
  description  = "Identity assumed by GitHub Actions via Workload Identity Federation"
}

# Grant Artifact Registry Writer to Deployer
resource "google_artifact_registry_repository_iam_member" "deployer_ar_writer" {
  location   = google_artifact_registry_repository.docker_repo.location
  repository = google_artifact_registry_repository.docker_repo.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.github_deployer.email}"
}

# Grant Cloud Run Admin to Deployer
resource "google_project_iam_member" "deployer_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.github_deployer.email}"
}

# Allow GitHub Deployer to act as the Cloud Run Runtime Service Account
resource "google_service_account_iam_member" "deployer_sa_user" {
  service_account_id = google_service_account.cloud_run_runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.github_deployer.email}"
}

# ==============================================================================
# 4. Workload Identity Federation (Keyless OIDC Auth)
# ==============================================================================
resource "google_iam_workload_identity_pool" "github_pool" {
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Workload Identity Pool"
  description               = "OIDC identity pool for GitHub Actions CI/CD workflows"

  depends_on = [google_project_service.enabled_apis]
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions-provider"
  display_name                       = "GitHub Actions OIDC Provider"
  description                        = "OIDC Provider for token.actions.githubusercontent.com"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  attribute_condition = "assertion.repository == '${var.github_repository}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Allow GitHub Actions (from the specific repo) to impersonate the Deployer Service Account
resource "google_service_account_iam_member" "wif_sa_impersonation" {
  service_account_id = google_service_account.github_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/${var.github_repository}"
}

# ==============================================================================
# 5. Google Cloud Run (v2 API) Microservice
# ==============================================================================
locals {
  full_image_url = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo.name}/${var.service_name}:${var.image_tag}"
}

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

  depends_on = [
    google_project_service.enabled_apis,
    google_artifact_registry_repository.docker_repo
  ]
}

# Public Ingress IAM Binding
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  count    = var.allow_unauthenticated ? 1 : 0
  name     = google_cloud_run_v2_service.app_service.name
  location = google_cloud_run_v2_service.app_service.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}
