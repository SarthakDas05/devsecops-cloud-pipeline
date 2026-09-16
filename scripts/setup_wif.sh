#!/usr/bin/env bash
# ==============================================================================
# Workload Identity Federation (WIF) Bootstrap Script
# Configures keyless OIDC authentication between GitHub Actions and Google Cloud.
# ==============================================================================
set -euo pipefail

# Required variables
PROJECT_ID="${1:-}"
GITHUB_REPO="${2:-}" # e.g. "your-username/devsecops-gcp-pipeline"
REGION="${3:-us-central1}"

if [ -z "$PROJECT_ID" ] || [ -z "$GITHUB_REPO" ]; then
    echo "Usage: $0 <GCP_PROJECT_ID> <GITHUB_USERNAME/REPO_NAME> [REGION]"
    echo "Example: $0 my-gcp-project-123 octocat/devsecops-gcp-pipeline us-central1"
    exit 1
fi

POOL_NAME="github-actions-pool"
PROVIDER_NAME="github-actions-provider"
SA_NAME="sa-github-deployer"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "================================================================="
echo " Bootstrapping Workload Identity Federation for GitHub Actions"
echo " Project:     $PROJECT_ID"
echo " GitHub Repo: $GITHUB_REPO"
echo " Region:      $REGION"
echo "================================================================="

# 1. Enable APIs
echo "[1/6] Enabling required Google Cloud APIs..."
gcloud services enable \
    iam.googleapis.com \
    iamcredentials.googleapis.com \
    sts.googleapis.com \
    run.googleapis.com \
    artifactregistry.googleapis.com \
    --project="$PROJECT_ID"

# 2. Create Service Account for GitHub Actions
echo "[2/6] Creating Deployer Service Account ($SA_EMAIL)..."
gcloud iam service-accounts create "$SA_NAME" \
    --display-name="GitHub Actions Deployer" \
    --project="$PROJECT_ID" || echo "Service account may already exist, continuing..."

# 3. Assign Required IAM Roles to Service Account
echo "[3/6] Binding IAM roles to $SA_EMAIL..."
for role in "roles/run.admin" "roles/artifactregistry.writer" "roles/iam.serviceAccountUser"; do
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$SA_EMAIL" \
        --role="$role" \
        --condition=None --quiet
done

# 4. Create Workload Identity Pool
echo "[4/6] Creating Workload Identity Pool ($POOL_NAME)..."
gcloud iam workload-identity-pools create "$POOL_NAME" \
    --project="$PROJECT_ID" \
    --location="global" \
    --display-name="GitHub Actions Pool" || echo "Pool may already exist, continuing..."

# 5. Create OIDC Provider
echo "[5/6] Creating Workload Identity Provider ($PROVIDER_NAME)..."
gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_NAME" \
    --project="$PROJECT_ID" \
    --location="global" \
    --workload-identity-pool="$POOL_NAME" \
    --display-name="GitHub Actions OIDC Provider" \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
    --attribute-condition="assertion.repository == '${GITHUB_REPO}'" || echo "Provider may already exist, continuing..."

# 6. Allow GitHub Actions repository to impersonate Service Account
echo "[6/6] Binding Workload Identity User role to GitHub repository assertion..."
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
WIF_PROVIDER_FULL="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_NAME}/providers/${PROVIDER_NAME}"

gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
    --project="$PROJECT_ID" \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_NAME}/attribute.repository/${GITHUB_REPO}" --quiet

echo "================================================================="
echo " Workload Identity Federation Setup Complete!"
echo " Add these Secrets to your GitHub Repository Settings -> Secrets:"
echo " 1. GCP_PROJECT_ID:                   $PROJECT_ID"
echo " 2. GCP_REGION:                       $REGION"
echo " 3. GCP_SERVICE_ACCOUNT:              $SA_EMAIL"
echo " 4. GCP_WORKLOAD_IDENTITY_PROVIDER:   $WIF_PROVIDER_FULL"
echo "================================================================="
