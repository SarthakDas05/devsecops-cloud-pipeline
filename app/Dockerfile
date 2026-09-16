# ==========================================
# Stage 1: Builder (Dependency compilation)
# ==========================================
FROM python:3.12-slim AS builder

WORKDIR /build

# Install build dependencies if needed
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY requirements.txt .

# hadolint ignore=DL3013
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ==========================================
# Stage 2: Hardened Runtime Container
# ==========================================
FROM python:3.12-slim AS runtime

# Metadata labels for container compliance
LABEL org.opencontainers.image.title="DevSecOps Cloud Run Microservice" \
      org.opencontainers.image.description="Hardened Python FastAPI microservice for Google Cloud Run" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.licenses="Apache-2.0"

# Security & runtime environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/install/bin:$PATH" \
    PYTHONPATH="/install/lib/python3.12/site-packages" \
    APP_PORT=8080

WORKDIR /app

# Create a non-privileged system user and group (UID/GID 10001)
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -s /sbin/nologin -M appuser

# Copy installed packages from builder
COPY --from=builder /install /install

# Copy application source code with ownership
COPY --chown=appuser:appgroup . /app/app/

# Switch to non-root user (Enforces Principle of Least Privilege)
USER 10001:10001

# Cloud Run defaults to container listening on port 8080
EXPOSE 8080

# Native healthcheck probe
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health', timeout=3)" || exit 1

# Start Uvicorn ASGI Server
CMD ["python3", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080", "--no-access-log"]
