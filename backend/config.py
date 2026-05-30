from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    openai_api_key: str = ""
    openai_base_url: str = "https://api.openai.com/v1"
    openai_model: str = "gpt-4o"

    ocr_engine: str = "easyocr"
    ocr_lang: str = "ch_sim"

    session_ttl_seconds: int = 1800

    max_video_size_mb: int = 500
    video_download_timeout: int = 120

    rate_limit: str = "60/minute"

    class Config:
        env_file = ".env"
        env_prefix = ""


settings = Settings()
