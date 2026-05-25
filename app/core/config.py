from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    APP_NAME: str = "ZED Proxy Bot"
    ENV: str = "production"
    BOT_TOKEN: str
    MAIN_ADMIN_ID: int
    ADMIN_USERNAME: str
    ADMIN_PASSWORD: str
    JWT_SECRET: str = "change-me"
    JWT_EXPIRE_MINUTES: int = 60
    DATABASE_URL: str
    REDIS_URL: str = "redis://redis:6379/0"
    DOMAIN: str = ""
    WEB_BASE_URL: str = "http://127.0.0.1:8000"
    USE_WEBHOOK: bool = False
    BOT_WEBHOOK_PATH: str = "/telegram/webhook"
    ADMIN_PATH: str = "/admin"
    API_PATH: str = "/api"
    CARD_NUMBER: str = ""
    CARD_HOLDER: str = ""
    K2K_ENABLED: bool = False
    REPORT_GROUP_CHAT_ID: str = ""
    REPORT_GROUP_ENABLED: bool = False
    FORCE_JOIN_ENABLED: bool = False
    FORCE_PHONE_ENABLED: bool = False


settings = Settings()
