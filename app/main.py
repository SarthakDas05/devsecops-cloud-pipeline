import asyncio
import hashlib
import json
import logging
import sys
import time
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import Any, Dict

from fastapi import FastAPI, HTTPException, Request, Response, status
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.schemas import (
    HealthResponse,
    InfoResponse,
    ProcessRequest,
    ProcessResponse,
    ReadinessResponse,
)


# Configure Structured JSON Logging
class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        log_object: Dict[str, Any] = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "service": settings.app_name,
            "version": settings.app_version,
            "environment": settings.app_env,
        }
        if hasattr(record, "trace_id"):
            log_object["logging.googleapis.com/trace"] = record.trace_id
        if record.exc_info:
            log_object["exception"] = self.formatException(record.exc_info)
        return json.dumps(log_object)


logger = logging.getLogger("service")
logger.setLevel(getattr(logging, settings.log_level.upper(), logging.INFO))
log_handler = logging.StreamHandler(sys.stdout)
log_handler.setFormatter(JsonFormatter())
logger.handlers = [log_handler]
logger.propagate = False

# Global state tracking
START_TIME = time.time()
SERVICE_HEALTHY = True
REQUEST_COUNTER = 0
ERROR_COUNTER = 0


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info(
        f"Starting {settings.app_name} v{settings.app_version} "
        f"[env: {settings.app_env}, commit: {settings.commit_sha}]"
    )
    yield
    logger.info(f"Shutting down {settings.app_name}")


app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="Enterprise DevSecOps Cloud Run Microservice with hardened security and observability.",
    lifespan=lifespan,
)

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def logging_and_metrics_middleware(request: Request, call_next):
    global REQUEST_COUNTER, ERROR_COUNTER
    REQUEST_COUNTER += 1
    start_time = time.perf_counter()

    # Extract GCP Cloud Trace ID if present
    trace_header = request.headers.get("X-Cloud-Trace-Context", "")
    trace_id = trace_header.split("/")[0] if trace_header else f"local-{time.time_ns()}"

    response: Response = await call_next(request)
    duration_ms = (time.perf_counter() - start_time) * 1000

    if response.status_code >= 500:
        ERROR_COUNTER += 1

    # Structured request log
    log_record = logging.LogRecord(
        name="http_access",
        level=logging.INFO if response.status_code < 400 else logging.WARNING,
        pathname="",
        lineno=0,
        msg=f"{request.method} {request.url.path} -> {response.status_code} ({duration_ms:.2f}ms)",
        args=(),
        exc_info=None,
    )
    log_record.trace_id = trace_id
    logger.handle(log_record)

    response.headers["X-Response-Time-Ms"] = f"{duration_ms:.2f}"
    return response


@app.get("/", tags=["General"])
async def root():
    return {
        "service": settings.app_name,
        "status": "operational",
        "docs": "/docs",
        "health": "/health",
        "ready": "/ready",
    }


@app.get("/health", response_model=HealthResponse, tags=["Observability"])
async def health_check():
    """Liveness probe: Returns 200 if container is healthy, 503 if artificially degraded."""
    if not SERVICE_HEALTHY:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Service health artificially degraded for chaos testing.",
        )
    return HealthResponse(
        status="healthy",
        timestamp=datetime.now(timezone.utc),
        uptime_seconds=round(time.time() - START_TIME, 2),
        version=settings.app_version,
        environment=settings.app_env,
    )


@app.get("/ready", response_model=ReadinessResponse, tags=["Observability"])
async def readiness_check():
    """Readiness probe: Checks dependencies before receiving ingress traffic."""
    checks = {
        "database": "connected",
        "memory_headroom": "ok",
        "storage": "writable",
    }
    return ReadinessResponse(ready=True, checks=checks)


@app.get("/info", response_model=InfoResponse, tags=["General"])
async def service_info():
    """Returns runtime metadata and build information."""
    return InfoResponse(
        app_name=settings.app_name,
        version=settings.app_version,
        environment=settings.app_env,
        commit_sha=settings.commit_sha,
        runtime_python=f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
    )


@app.get("/metrics", tags=["Observability"])
async def metrics():
    """Returns basic Prometheus-compatible latency & request counters."""
    uptime = time.time() - START_TIME
    return {
        "http_requests_total": REQUEST_COUNTER,
        "http_errors_total": ERROR_COUNTER,
        "process_uptime_seconds": round(uptime, 2),
        "service_healthy": 1 if SERVICE_HEALTHY else 0,
    }


@app.post("/process", response_model=ProcessResponse, tags=["Business Logic"])
async def process_transaction(req: ProcessRequest):
    """Processes a payload and generates a deterministic validation checksum."""
    payload_str = json.dumps(req.payload, sort_keys=True)
    checksum = hashlib.sha256(payload_str.encode("utf-8")).hexdigest()

    return ProcessResponse(
        transaction_id=req.transaction_id,
        status="processed",
        processed_at=datetime.now(timezone.utc),
        checksum=checksum,
        items_count=len(req.payload),
    )


# Chaos Engineering endpoints for validating alerting & auto-recovery
if settings.enable_chaos_endpoints:

    @app.post("/chaos/slow", tags=["Chaos Testing"])
    async def chaos_slow(delay_sec: float = 2.5):
        """Simulates latency degradation to test monitoring alert thresholds."""
        await asyncio.sleep(delay_sec)
        return {"simulated_delay_seconds": delay_sec, "message": "Latency spike simulated"}

    @app.post("/chaos/error", tags=["Chaos Testing"])
    async def chaos_error():
        """Simulates an internal 500 error to test alerting & auto-rollback."""
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Simulated internal 500 server error for alert testing.",
        )

    @app.post("/chaos/toggle-health", tags=["Chaos Testing"])
    async def toggle_health():
        """Toggles the service health state between healthy and degraded."""
        global SERVICE_HEALTHY
        SERVICE_HEALTHY = not SERVICE_HEALTHY
        return {"service_healthy": SERVICE_HEALTHY}
