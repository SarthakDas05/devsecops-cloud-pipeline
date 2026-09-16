# Enterprise DevSecOps & GitOps Cloud Delivery Pipeline

[![DevSecOps Pipeline](https://img.shields.io/badge/Security-Trivy%20%7C%20Hadolint%20%7C%20Secretlint%20%7C%20Bandit-blue.svg)](https://github.com/SarthakDas05/devsecops-cloud-pipeline)
[![Cloud Provider](https://img.shields.io/badge/Cloud-Google%20Cloud%20Platform-red.svg)](https://cloud.google.com/)
[![Compute](https://img.shields.io/badge/Compute-Cloud%20Run%20(v2)-green.svg)](https://cloud.google.com/run)
[![IaC](https://img.shields.io/badge/IaC-Terraform%201.8%2B-purple.svg)](https://www.terraform.io/)
[![Auth](https://img.shields.io/badge/Auth-Keyless%20OIDC%20WIF-orange.svg)](https://cloud.google.com/iam/docs/workload-identity-federation)
[![License](https://img.shields.io/badge/License-Apache%202.0-black.svg)](LICENSE)

---

## 1. Executive Summary & Objective

This repository contains a **production-grade, zero-trust DevSecOps and GitOps delivery pipeline** deploying a hardened, containerized **FastAPI microservice** to **Google Cloud Run (v2)**.

### Core Problems Solved
1. **Elimination of Static Credentials:** Traditional CI/CD setups store long-lived JSON service account keys in GitHub Secrets. If leaked or compromised, they provide persistent, uncontrolled access. This project enforces **Keyless OpenID Connect (OIDC)** via **Google Cloud Workload Identity Federation (WIF)**.
2. **Shift-Left Security Gates:** Five distinct security layers (Python SAST, Secret Scanning, Dockerfile Linting, Container CVE Scanning, and SBOM generation) prevent security debt and vulnerable code from reaching production.
3. **Reproducible Infrastructure as Code (IaC):** Modular **Terraform** provisions all Google Cloud resources (Artifact Registry, Service Accounts, IAM Bindings, WIF, and Cloud Run) with state locking and least-privilege scoping.
4. **Resilient Linux Observability:** A custom Linux Bash daemon and `systemd` service tracks endpoint availability and microsecond network latency stages, emitting structured JSON logs compatible with Cloud Logging and SIEM tooling.

---

## 2. End-to-End Architecture

```
                                  SHIFT-LEFT DEVSECOPS PIPELINE
   [ Developer Commit / PR ]
               │
               ▼
   [ GitHub Actions CI / PR Gates ]
     ├── 1. Code Quality & Formatting ───────> Ruff (PEP8 + Style Rules)
     ├── 2. Python SAST Security Scan ───────> Bandit (Injection & Insecure Imports)
     ├── 3. Secrets Detection Gate ──────────> Secretlint (API Keys, Tokens, Passwords)
     ├── 4. Dockerfile Best Practices ───────> Hadolint (Layer Optimization & Security)
     ├── 5. Unit & Integration Tests ────────> Pytest (Code Coverage >= 95%)
     ├── 6. Container CVE Vulnerability ─────> Trivy (Fails build on CRITICAL / HIGH)
     └── 7. Software Supply Chain (SBOM) ────> CycloneDX SBOM Generation
               │
               ▼ (Merge to main)
   [ GitHub Actions CD Deployment ]
     ├── 8. Keyless Cloud Auth ──────────────> Workload Identity Federation (OIDC)
     ├── 9. Secure Container Push ───────────> Google Artifact Registry (SHA Digest)
     └── 10. GitOps Infrastructure Rollout ──> Terraform Plan & Apply
               │
               ▼
   [ Google Cloud Platform ]
     ├── Compute: Google Cloud Run (v2 Autoscaling, Startup/Liveness Probes)
     ├── IAM: Least-Privilege Service Accounts (Runtime vs Deployer)
     └── Logs & Metrics: Structured JSON Logging & Cloud Trace Correlation
               │
               ▼
   [ Linux Observability & Self-Healing ]
     ├── Linux Daemon (`health_monitor.sh` + systemd)
     ├── Microsecond Latency Tracking (DNS, TCP, TTFB, Total)
     └── Automated Chaos & Alert Threshold Validation
```

---

## 3. Five-Layer Security Architecture

| Security Layer | Tool / Mechanism | Enforced Standard / Policy |
| :--- | :--- | :--- |
| **Layer 1: Static Code Analysis (SAST)** | `Bandit` & `Ruff` | Scans Python code for AST-level security vulnerabilities, insecure deserialization, and unsafe subprocess calls. |
| **Layer 2: Secret & Token Detection** | `Secretlint` | Scans commits and files for hardcoded private keys, cloud tokens, passwords, and sensitive certificates. |
| **Layer 3: Dockerfile Security Linting** | `Hadolint` | Enforces container security best practices (no untracked root installations, non-cached apt layers, explicit tags). |
| **Layer 4: Container CVE Scanning & SBOM** | `Trivy` & `CycloneDX` | Scans OS packages and application dependencies against CVE databases; blocks pipeline if `CRITICAL` or `HIGH` vulnerabilities exist. Generates compliant SBOM. |
| **Layer 5: Zero-Trust Keyless Cloud Auth** | `GCP Workload Identity Federation` | Exchanges short-lived GitHub OIDC tokens for temporary Google OAuth tokens. Zero permanent credentials stored in GitHub Secrets. |

---

## 4. Repository Structure

```text
devsecops-gcp-pipeline/
├── .github/
│   └── workflows/
│       ├── ci-pr.yml                 # PR validation workflow (Lint + SAST + Hadolint + Trivy + Tests)
│       └── deploy.yml                # Production CD pipeline (WIF OIDC + Build + Push + Terraform Apply)
├── app/
│   ├── main.py                       # FastAPI application (Probes, Metrics, Structured Logging, Chaos)
│   ├── config.py                     # Configuration management with Pydantic Settings
│   ├── schemas.py                    # Pydantic v2 request/response contracts
│   ├── requirements.txt              # Pinned production dependencies
│   ├── requirements-dev.txt          # Development, testing, and security scanning dependencies
│   ├── Dockerfile                    # Hardened multi-stage Dockerfile (Non-root UID 10001)
│   ├── .dockerignore                 # Excludes local artifacts and secrets from container context
│   └── tests/
│       ├── __init__.py
│       ├── conftest.py               # Test fixtures and FastAPI TestClient
│       └── test_main.py              # Unit and integration test suite
├── scripts/
│   ├── health_monitor.sh             # Linux Bash health & microsecond latency monitoring daemon
│   ├── service_health.service        # Systemd service unit definition
│   ├── setup_wif.sh                  # Bootstrap GCP Workload Identity Federation & IAM
│   └── local_devsecops_check.sh      # Local DevSecOps simulation runner
├── terraform/
│   ├── backend.tf                    # GCS remote state configuration & provider constraints
│   ├── main.tf                       # Cloud Run, Artifact Registry, WIF, and IAM definitions
│   ├── variables.tf                  # Infrastructure input variable specifications
│   ├── outputs.tf                    # Service URL, WIF provider, and Registry outputs
│   └── terraform.tfvars.example      # Example configuration template
├── Makefile                          # Developer automation (test, lint, scan, run, monitor)
├── .gitignore                        # Git exclusion rules
└── README.md                         # Project documentation and interview guide
```

---

## 5. Local Quickstart & Developer Experience

You can run and test every component locally using the provided `Makefile`:

### 1. Setup Virtual Environment
```bash
python3 -m venv .venv
source .venv/bin/activate
make install-dev
```

### 2. Run Test Suite with Coverage
```bash
make test
```

### 3. Run Static Analysis & Linters
```bash
make lint
```

### 4. Build and Run Hardened Container
```bash
make docker-build
make docker-run
```

### 5. Execute Health Monitor Daemon Against Local Instance
```bash
# In another terminal:
make monitor
```

### 6. Run Complete Local DevSecOps Suite
```bash
make devsecops-check
```

---

## 6. Google Cloud Setup & Keyless OIDC Deployment

### Step 1: Bootstrap Workload Identity Federation in GCP
Run the automated bootstrap script using the `gcloud` CLI:
```bash
chmod +x scripts/setup_wif.sh
./scripts/setup_wif.sh "<YOUR_GCP_PROJECT_ID>" "<GITHUB_USERNAME/REPO_NAME>" "us-central1"
```

### Step 2: Configure GitHub Repository Secrets
In your GitHub repository, navigate to **Settings > Secrets and variables > Actions** and add the following repository secrets:

| Secret Name | Description / Example Value |
| :--- | :--- |
| `GCP_PROJECT_ID` | Your Google Cloud Project ID (e.g. `my-company-prod-1029`) |
| `GCP_REGION` | GCP Deployment Region (e.g. `us-central1`) |
| `GCP_SERVICE_ACCOUNT` | Deployer SA email (e.g. `sa-github-deployer@my-company-prod-1029.iam.gserviceaccount.com`) |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Full WIF provider resource name (e.g. `projects/123456789/locations/global/workloadIdentityPools/github-actions-pool/providers/github-actions-provider`) |

### Step 3: Trigger Production Deployment
Commit and push your code to the `main` branch:
```bash
git add .
git commit -m "feat: initial enterprise devsecops deployment"
git push origin main
```
GitHub Actions will authenticate keylessly, build the container, run vulnerability scans, push the image to Google Artifact Registry, and apply Terraform to deploy your service to Google Cloud Run.

---

## 7. Linux Observability & Self-Healing Daemon

The Linux daemon script (`scripts/health_monitor.sh`) continuously checks service health, measures microsecond latency stages, and outputs structured JSON logs:

```json
{
  "timestamp": "2026-08-24T03:25:00Z",
  "service_url": "https://devsecops-cloud-microservice-xyz-uc.a.run.app/health",
  "status_code": 200,
  "healthy": true,
  "latency_degraded": false,
  "metrics": {
    "dns_sec": 0.002,
    "connect_sec": 0.015,
    "ttfb_sec": 0.045,
    "total_sec": 0.048
  }
}
```

### Running as a 24/7 Systemd Service
On a Linux monitoring host or bastion VM:
```bash
sudo cp scripts/health_monitor.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/health_monitor.sh
sudo cp scripts/service_health.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now service_health
sudo journalctl -u service_health -f
```

---

## 8. Resume STAR Bullets & Interview Talking Points

### 🎯 Resume Bullet
> *"Engineered an enterprise DevSecOps delivery pipeline using GitHub Actions, Terraform, and Google Cloud Run; eliminated static credentials by implementing keyless Workload Identity Federation (WIF) and integrated Trivy CVE gates, Bandit SAST, and automated Linux health daemons to enforce zero-trust CI/CD."*

### 🎙️ Interview Q&A Cheatsheet

#### Q1: "Why did you use Workload Identity Federation instead of standard Service Account Keys?"
> **Answer:** *"Storing permanent service account JSON keys in GitHub Secrets creates high security risk: keys do not automatically rotate, can be accidentally leaked in logs, and provide unbounded access if compromised. Workload Identity Federation implements keyless authentication: GitHub generates a short-lived OIDC token (valid for ~5 minutes) signed by GitHub's authority. GCP STS validates the cryptographic signature and token claims (like repository name and branch) before issuing a temporary OAuth access token with strictly scoped permissions."*

#### Q2: "How did you design container security in this project?"
> **Answer:** *"I implemented a defense-in-depth container security strategy: First, I used a multi-stage Dockerfile that builds dependencies in an ephemeral builder stage and copies only compiled packages into a minimal runtime image. Second, the container executes under a dedicated non-root user (UID 10001:appuser) to prevent container escape exploits. Third, Hadolint lints Dockerfile instructions against CIS benchmarks in CI, and Trivy scans the final image for CVEs, failing the pipeline if any Critical or High vulnerabilities exist."*

#### Q3: "How does the pipeline prevent breaking changes in production?"
> **Answer:** *"We use a two-tier GitOps workflow: On Pull Requests (`ci-pr.yml`), code is linted with Ruff, scanned with Bandit and Secretlint, tested via Pytest with coverage reporting, and Terraform configuration is validated with `terraform fmt` and `terraform validate`. Only after all automated gates pass and code is merged to `main` does `deploy.yml` execute `terraform apply` to roll out a new Cloud Run revision."*

---

## 9. License
Licensed under the Apache License, Version 2.0.
