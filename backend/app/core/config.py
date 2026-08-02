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
    account_deletion_reauth_max_age_seconds: int = Field(default=300, ge=60, le=3600)

    plantnet_api_key: str | None = None
    plantnet_base_url: str = "https://my-api.plantnet.org/v2"
    plantnet_project: str = "all"
    plantnet_language: str = "en"
    plantnet_result_limit: int = Field(default=5, ge=1, le=20)
    plantnet_timeout_seconds: float = Field(default=20.0, gt=0)

    kindwise_api_key: str | None = None
    kindwise_base_url: str = "https://api.plant.id/v3"
    kindwise_language: str = "ko"
    kindwise_timeout_seconds: float = Field(default=45.0, gt=0)

    openai_api_key: str | None = None
    openai_chat_model: str = "gpt-5-mini"
    openai_timeout_seconds: float = Field(default=45.0, gt=0)
    openai_chat_max_output_tokens: int = Field(default=800, ge=100, le=4000)
    ai_chat_context_message_limit: int = Field(default=20, ge=4, le=100)
    ai_chat_summary_trigger_count: int = Field(default=30, ge=10, le=200)
    ai_chat_summary_batch_size: int = Field(default=20, ge=5, le=100)

    firebase_project_id: str = "leafie-2c528"
    fcm_credentials_json: str | None = None

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
