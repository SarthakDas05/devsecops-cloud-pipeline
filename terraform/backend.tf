terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.30.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.30.0"
    }
  }

  # Remote State Backend (Google Cloud Storage)
  # To enable GCS remote backend in production, uncomment the block below:
  # backend "gcs" {
  #   bucket = "YOUR_GCP_PROJECT_ID-tfstate"
  #   prefix = "devsecops-pipeline/state"
  # }
}
