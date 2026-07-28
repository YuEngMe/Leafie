from functools import lru_cache
from typing import Literal

from pydantic import Field, computed_field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_env: Literal["local", "test", "staging", "production"] = "local"
    app_name: str = "Leafie API"
    api_v1_prefix: str = "/api/v1"
    log_level: str = "INFO"

    supabase_url: str | None = None
    supabase_publishable_key: str | None = None
    supabase_secret_key: str | None = None
    supabase_jwks_url: str | None = None
    supabase_jwt_issuer: str | None = None
    supabase_jwt_audience: str = "authenticated"
    supabase_storage_bucket: str = "leafie-media"
    media_download_url_expires_seconds: int = 300
    supabase_queue_name: str = "leafie_jobs"

    plantnet_api_key: str | None = None
    plantnet_base_url: str = "https://my-api.plantnet.org/v2"
    plantnet_project: str = "all"
    plantnet_language: str = "en"
    plantnet_result_limit: int = Field(default=5, ge=1, le=20)
    plantnet_timeout_seconds: float = Field(default=20.0, gt=0)

    worker_poll_interval_seconds: float = Field(default=1.0, gt=0)
    worker_visibility_timeout_seconds: int = Field(default=60, ge=1)
    worker_max_attempts: int = Field(default=3, ge=1)
    worker_retry_base_seconds: int = Field(default=5, ge=1)
    worker_retry_max_seconds: int = Field(default=300, ge=1)
    worker_batch_size: int = Field(default=5, ge=1, le=100)

    database_url: str | None = None

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @computed_field
    @property
    def resolved_supabase_jwks_url(self) -> str | None:
        if self.supabase_jwks_url:
            return self.supabase_jwks_url
        if self.supabase_url:
            return f"{self.supabase_url.rstrip('/')}/auth/v1/.well-known/jwks.json"
        return None

    @computed_field
    @property
    def resolved_supabase_jwt_issuer(self) -> str | None:
        if self.supabase_jwt_issuer:
            return self.supabase_jwt_issuer
        if self.supabase_url:
            return f"{self.supabase_url.rstrip('/')}/auth/v1"
        return None


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
