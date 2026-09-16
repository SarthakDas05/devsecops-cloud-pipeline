from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field


class Settings(BaseSettings):
    """Application configuration loaded from environment variables with sensible defaults."""
    app_name: str = Field(default="devsecops-cloud-microservice", description="Service name")
    app_version: str = Field(default="1.0.0", description="Semantic release version")
    app_env: str = Field(default="production", description="Environment: development, staging, production")
    commit_sha: str = Field(default="local-dev", description="Git commit hash from CI build")
    port: int = Field(default=8080, description="Port to listen on (Cloud Run defaults to 8080)")
    log_level: str = Field(default="INFO", description="Logging verbosity")
    enable_chaos_endpoints: bool = Field(default=True, description="Enable chaos engineering testing endpoints")

    model_config = SettingsConfigDict(env_prefix="APP_", case_sensitive=False)


settings = Settings()
