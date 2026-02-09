"""Application configuration settings."""
from functools import lru_cache
from typing import Optional, List
from pydantic_settings import BaseSettings
import os
import logging

logger = logging.getLogger(__name__)


def get_secret_from_gcp(secret_name: str) -> Optional[str]:
    """Fetch secret from GCP Secret Manager."""
    try:
        from google.cloud import secretmanager

        project_id = os.environ.get("GCP_PROJECT_ID")
        if not project_id:
            return None

        client = secretmanager.SecretManagerServiceClient()
        name = f"projects/{project_id}/secrets/{secret_name}/versions/latest"
        response = client.access_secret_version(request={"name": name})
        return response.payload.data.decode("UTF-8")
    except Exception as e:
        logger.warning(f"Could not fetch secret {secret_name} from Secret Manager: {e}")
        return None


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # App
    app_name: str = "WhyTheyBuy"
    app_url: str = "http://localhost:3000"
    api_url: str = "http://localhost:8000"
    debug: bool = False

    # GCP Settings
    gcp_project_id: Optional[str] = None
    gcp_region: str = "us-central1"
    use_cloud_sql_connector: bool = False
    cloud_sql_instance_connection_name: Optional[str] = None  # project:region:instance

    # Database
    database_url: str = "postgresql://postgres:postgres@localhost:5432/whytheybuy"
    db_user: Optional[str] = None
    db_pass: Optional[str] = None
    db_name: str = "whytheybuy"

    # Redis
    redis_url: str = "redis://localhost:6379/0"
    redis_host: Optional[str] = None
    redis_port: int = 6379
    redis_password: Optional[str] = None

    # JWT Auth
    jwt_secret_key: str = "your-super-secret-key-change-in-production"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 7

    # CORS - comma-separated list of allowed origins for production
    cors_origins: str = ""  # e.g., "https://yourdomain.com,https://www.yourdomain.com"

    # External APIs
    openai_api_key: Optional[str] = None
    anthropic_api_key: Optional[str] = None
    alpha_vantage_api_key: Optional[str] = None
    polygon_api_key: Optional[str] = None
    finnhub_api_key: Optional[str] = None

    # Stripe
    stripe_secret_key: Optional[str] = None
    stripe_webhook_secret: Optional[str] = None
    stripe_price_id_pro_monthly: Optional[str] = None
    stripe_price_id_pro_yearly: Optional[str] = None

    # SendGrid
    sendgrid_api_key: Optional[str] = None
    from_email: str = "noreply@whytheybuy.com"

    # Rate Limits
    rate_limit_requests_per_minute: int = 60

    # AI Settings
    ai_provider: str = "gemini"  # gemini, openai, or anthropic
    ai_model: str = "gemini-3-flash-preview"  # Default Gemini 3 model - "gemini-2.0-flash"
    gemini_api_key: Optional[str] = None
    gemini_model: str = "gemini-3-flash-preview"  # Gemini 3 model for multimodal

    # Cloud Storage (for file uploads in production)
    gcs_bucket_name: Optional[str] = None

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False

    def get_cors_origins(self) -> List[str]:
        """Get list of CORS origins."""
        if self.cors_origins:
            return [origin.strip() for origin in self.cors_origins.split(",")]
        return []

    def get_redis_url(self) -> str:
        """Build Redis URL from components or use direct URL."""
        if self.redis_host:
            auth = f":{self.redis_password}@" if self.redis_password else ""
            return f"redis://{auth}{self.redis_host}:{self.redis_port}/0"
        return self.redis_url


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance."""
    settings = Settings()

    # Try to load secrets from GCP Secret Manager if project ID is set
    if settings.gcp_project_id:
        # Load sensitive values from Secret Manager
        secret_mappings = {
            "jwt-secret-key": "jwt_secret_key",
            "gemini-api-key": "gemini_api_key",
            "stripe-secret-key": "stripe_secret_key",
            "stripe-webhook-secret": "stripe_webhook_secret",
            "sendgrid-api-key": "sendgrid_api_key",
            "openai-api-key": "openai_api_key",
            "anthropic-api-key": "anthropic_api_key",
            "db-password": "db_pass",
            "redis-password": "redis_password",
        }

        for secret_name, attr_name in secret_mappings.items():
            if not getattr(settings, attr_name, None):
                secret_value = get_secret_from_gcp(secret_name)
                if secret_value:
                    object.__setattr__(settings, attr_name, secret_value)

    return settings


settings = get_settings()
