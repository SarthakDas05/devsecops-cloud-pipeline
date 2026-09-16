from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    status: str = Field(
        json_schema_extra={"example": "healthy"},
        description="Service health status: healthy, degraded, unhealthy",
    )
    timestamp: datetime = Field(description="UTC timestamp of the health check")
    uptime_seconds: float = Field(description="Seconds since service start")
    version: str = Field(description="Application version")
    environment: str = Field(description="Running environment")


class ReadinessResponse(BaseModel):
    ready: bool = Field(
        json_schema_extra={"example": True}, description="Readiness status for receiving traffic"
    )
    checks: Dict[str, str] = Field(description="Status of internal subsystem checks")


class InfoResponse(BaseModel):
    app_name: str
    version: str
    environment: str
    commit_sha: str
    runtime_python: str


class ProcessRequest(BaseModel):
    transaction_id: str = Field(
        ..., min_length=3, max_length=64, description="Unique transaction reference ID"
    )
    payload: Dict[str, Any] = Field(..., description="Arbitrary transactional data payload")
    tags: Optional[List[str]] = Field(
        default_factory=list, description="Optional categorization tags"
    )


class ProcessResponse(BaseModel):
    transaction_id: str
    status: str = Field(json_schema_extra={"example": "processed"})
    processed_at: datetime
    checksum: str
    items_count: int
