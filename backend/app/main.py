import logging
from fastapi import FastAPI, APIRouter, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from app.api import auth, documents, user, ai, notifications, chat, multilingual
from app.core.config import settings
from app.db.session import Base
from app import models

# Configure logger
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Database tables creation is handled by Firestore dynamically
Base.metadata.create_all()

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json"
)

@app.on_event("startup")
async def startup_event():
    logger.info("[Startup] Running startup validation checks...")
    
    # 1. Database connectivity check
    from app.services.firebase_service import firebase_service
    db_ok = firebase_service.check_connectivity()
    if not db_ok:
        logger.critical("[Startup] Database connectivity check failed! Please verify DATABASE_URL and pooler configuration.")
        
    # 2. Email/SMTP configuration check
    from app.services.email_service import email_service
    email_ok = email_service.validate_configuration()
    if not email_ok:
        logger.warning("[Startup] Email/SMTP configuration check failed! OTP features might be unavailable.")

# Set all CORS enabled origins
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify real origins for Flutter web or apps
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include Routers
debug_router = APIRouter()

@debug_router.post("/test-email")
async def test_email_endpoint(recipient: str = None):
    from app.services.email_service import email_service
    import smtplib
    import socket
    
    if not recipient:
        recipient = settings.SMTP_EMAIL
        
    if not recipient:
        raise HTTPException(
            status_code=400,
            detail="No recipient email provided, and SMTP_EMAIL settings key is empty."
        )
        
    logger.info(f"[Debug API] test-email called. Target recipient: {recipient}")
    
    try:
        res = email_service.run_smtp_diagnostics(recipient)
        return res
    except Exception as e:
        logger.error(f"[Debug API] SMTP Connection / Diagnostic Failure: {type(e).__name__}: {str(e)}", exc_info=True)
        
        if isinstance(e, socket.gaierror):
            detail = f"DNS failure: Could not resolve SMTP server. Details: {str(e)}"
        elif isinstance(e, (socket.timeout, TimeoutError)):
            detail = f"Network timeout: Connection to SMTP server timed out. Details: {str(e)}"
        elif isinstance(e, smtplib.SMTPAuthenticationError):
            detail = f"SMTP Authentication Failure (Code {e.smtp_code}): {e.smtp_error.decode() if isinstance(e.smtp_error, bytes) else str(e.smtp_error)}"
        elif isinstance(e, (smtplib.SMTPSenderRefused, smtplib.SMTPRecipientsRefused, smtplib.SMTPDataError)):
            detail = f"SMTP Rejection Failure: {str(e)}"
        else:
            detail = f"Diagnostic Failure: {type(e).__name__}: {str(e)}"
            
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=detail
        )

app.include_router(debug_router, prefix=f"{settings.API_V1_STR}/debug", tags=["debug"])
app.include_router(auth.router, prefix=f"{settings.API_V1_STR}/auth", tags=["authentication"])
app.include_router(documents.router, prefix=f"{settings.API_V1_STR}/documents", tags=["documents"])
app.include_router(user.router, prefix=f"{settings.API_V1_STR}/user", tags=["user"])
app.include_router(ai.router, prefix=f"{settings.API_V1_STR}/ai", tags=["ai"])
app.include_router(chat.router, prefix=f"{settings.API_V1_STR}/chat", tags=["chat"])
app.include_router(multilingual.router, prefix=f"{settings.API_V1_STR}/multilingual", tags=["multilingual"])
app.include_router(notifications.router, prefix=f"{settings.API_V1_STR}/notifications", tags=["notifications"])

@app.get("/")
def root():
    return {"message": "Welcome to LexGuard AI Backend API"}
