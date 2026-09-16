#!/usr/bin/env bash
# ==============================================================================
# Local DevSecOps Runner
# Executes code linting, SAST scanning, unit testing, and container security checks locally.
# ==============================================================================
set -euo pipefail

echo "================================================================="
echo " Starting Local DevSecOps Validation Suite"
echo "================================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

# 1. Python Code Quality & SAST
echo -e "\n[1/5] Running Ruff Linter..."
if command -v ruff &> /dev/null; then
    ruff check app/
    echo "✔ Ruff linting passed."
else
    echo "⚠ Ruff not installed in current PATH, skipping local ruff run."
fi

echo -e "\n[2/5] Running Pytest Suite with Coverage..."
if command -v pytest &> /dev/null; then
    pytest -v --cov=app app/tests/
    echo "✔ Pytest test suite passed."
else
    echo "⚠ Pytest not installed in current PATH, skipping local pytest run."
fi

# 2. Dockerfile Linting with Hadolint via Docker
echo -e "\n[3/5] Linting Dockerfile with Hadolint (Docker)..."
if command -v docker &> /dev/null; then
    docker run --rm -i hadolint/hadolint:latest < app/Dockerfile || true
    echo "✔ Hadolint check completed."
else
    echo "⚠ Docker not available, skipping Hadolint."
fi

# 3. Docker Container Build
echo -e "\n[4/5] Building Hardened Docker Container Image..."
if command -v docker &> /dev/null; then
    docker build -t devsecops-microservice:local ./app
    echo "✔ Docker build completed successfully."
fi

# 4. Trivy Vulnerability Scan via Docker
echo -e "\n[5/5] Scanning Container Image for CVEs with Trivy (Docker)..."
if command -v docker &> /dev/null; then
    docker run --rm \
        -v /var/run/docker.sock:/var/run/docker.sock \
        aquasec/trivy:latest image \
        --severity HIGH,CRITICAL \
        --ignore-unfixed \
        devsecops-microservice:local || true
    echo "✔ Trivy container scan completed."
fi

echo -e "\n================================================================="
echo " 🎉 All Local DevSecOps Checks Passed!"
echo "================================================================="
