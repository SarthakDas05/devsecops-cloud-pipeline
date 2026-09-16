variable "project_id" {
  type        = string
  description = "The Google Cloud Platform Project ID."
}

variable "region" {
  type        = string
  description = "The GCP region to deploy resources into."
  default     = "us-central1"
}

variable "service_name" {
  type        = string
  description = "The name of the Google Cloud Run microservice."
  default     = "devsecops-cloud-microservice"
}

variable "artifact_registry_name" {
  type        = string
  description = "The name of the Google Artifact Registry Docker repository."
  default     = "cloud-microservices"
}

variable "image_tag" {
  type        = string
  description = "The container image tag / SHA to deploy."
  default     = "latest"
}

variable "github_repository" {
  type        = string
  description = "The GitHub repository (format: 'username/repo-name') permitted to authenticate via Workload Identity Federation."
  default     = "SarthakDas05/devsecops-cloud-pipeline"
}

variable "min_instances" {
  type        = number
  description = "Minimum number of Cloud Run instances to keep warm."
  default     = 0
}

variable "max_instances" {
  type        = number
  description = "Maximum number of Cloud Run instances for autoscaling."
  default     = 5
}

variable "allow_unauthenticated" {
  type        = bool
  description = "Whether to allow unauthenticated public invocations to the Cloud Run service."
  default     = true
}
