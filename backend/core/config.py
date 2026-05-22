from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # App
    APP_NAME: str = "Velya Server"
    VERSION: str = "1.0.0"
    DEBUG: bool = False

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://velya:velya@localhost:5432/velya"

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"

    # Security
    SECRET_KEY: str = "change-me-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 30  # 30 days

    # CORS
    CORS_ORIGINS: list[str] = [
        "http://localhost:5173",  # Vite dev
        "https://velya.kevinn.ie",
    ]

    # Webhook
    WEBHOOK_RATE_LIMIT: int = 10  # requests per minute

    class Config:
        env_file = ".env"


@lru_cache
def get_settings() -> Settings:
    return Settings()
