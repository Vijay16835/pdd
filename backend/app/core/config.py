from pydantic_settings import BaseSettings
import os
from dotenv import load_dotenv

load_dotenv()


class Settings(BaseSettings):
    PROJECT_NAME: str = "LexGuard AI"
    API_V1_STR: str = "/api/v1"
    SECRET_KEY: str = "your-secret-key-for-jwt-keep-it-safe"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 11520

    POSTGRES_SERVER: str = "aws-0-eu-central-1.pooler.supabase.com"
    POSTGRES_USER: str = "postgres.jrrbplpzqzvvtwyqomdi"
    POSTGRES_PASSWORD: str = "[YOUR-SUPABASE-PASSWORD]"
    POSTGRES_DB: str = "postgres"

    DATABASE_URL: str = "postgresql://postgres.jrrbplpzqzvvtwyqomdi:[YOUR-SUPABASE-PASSWORD]@aws-0-eu-central-1.pooler.supabase.com:6543/postgres"

    FIREBASE_CREDENTIALS_PATH: str = "firebase_credentials.json"
    FIREBASE_STORAGE_BUCKET: str = "lexguard-ai.appspot.com"

    SUPABASE_URL: str = ""
    SUPABASE_KEY: str = ""

    OPENAI_API_KEY: str = ""
    GOOGLE_API_KEY: str = ""
    GROQ_API_KEY: str = ""
    GROQ_MODEL: str = "llama-3.3-70b-versatile"

    SMTP_EMAIL: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_SERVER: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    
    # OCR Settings
    TESSERACT_CMD: str = os.environ.get("TESSERACT_CMD", "/usr/bin/tesseract")

    UPLOAD_DIR: str = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "uploads")

    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()

# Ensure upload directory exists
os.makedirs(settings.UPLOAD_DIR, exist_ok=True)