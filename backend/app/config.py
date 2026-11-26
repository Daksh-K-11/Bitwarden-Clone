"""Runtime configuration (environment variables / .env). No secrets in code."""

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # Cloudflare R2 (S3-compatible). Credentials live ONLY on this server.
    r2_account_id: str = ""
    r2_access_key_id: str = ""
    r2_secret_access_key: str = ""
    r2_bucket: str = "citadel-vault"

    # Firebase Admin: project id + service account JSON path
    # (GOOGLE_APPLICATION_CREDENTIALS is read by the Admin SDK itself).
    firebase_project_id: str = ""

    # Reject requests without a valid Firebase App Check token.
    require_app_check: bool = False

    # Require the Firebase account's email to be verified.
    require_email_verified: bool = True

    # Presigned URL lifetime (seconds). Short-lived by design.
    url_ttl_seconds: int = Field(default=300, ge=30, le=3600)

    # Size caps for encrypted objects (bytes).
    max_attachment_bytes: int = 110 * 1024 * 1024
    max_backup_bytes: int = 512 * 1024 * 1024

    # Simple per-user request budget (requests per minute).
    rate_limit_per_minute: int = 120

    @property
    def r2_endpoint(self) -> str:
        return f"https://{self.r2_account_id}.r2.cloudflarestorage.com"

    @property
    def r2_configured(self) -> bool:
        return bool(self.r2_account_id and self.r2_access_key_id and self.r2_secret_access_key)


@lru_cache
def get_settings() -> Settings:
    return Settings()
