from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from app.db.session import get_db
from app.models.user import User
from app.schemas.auth import UserCreate, UserLogin, Token, OTPVerify, ForgotPassword, ResetPassword, GoogleAuth, SendOTP, ChangePassword
from app.core.security import get_password_hash, create_access_token
from app.services.auth_service import signup_user, login_user, authenticate_google_user
from app.services.auth_service import change_password as change_pwd_service
from app.services.email_service import email_service
from app.api.deps import get_current_user
from datetime import datetime, timedelta, timezone
import random
import string
import logging
import asyncio
from app.services.document_service import get_user_storage_usage_mb

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/signup")
async def signup(user_in: UserCreate, db = Depends(get_db)):
    email = user_in.email.lower().strip()
    logger.info(f"[Auth API] /signup entry: email='{email}', name='{user_in.full_name}'")
    try:
        # Check if user already exists in Firestore
        user_data = db.get_user_by_email(email)
        if user_data:
            if user_data.get("is_verified"):
                logger.warning(f"[Auth API] /signup conflict: User with email '{email}' already exists and is verified.")
                raise HTTPException(status_code=400, detail="User with this email already exists")
            # If not verified, overwrite password and full_name
            logger.info(f"[Auth API] /signup: Existing unverified user '{email}' found. Overwriting name and password.")
            db.update_user(user_data["id"], {
                "full_name": user_in.full_name,
                "hashed_password": get_password_hash(user_in.password),
                "updated_at": datetime.now(timezone.utc).isoformat()
            })
            user_id = user_data["id"]
        else:
            # Create user in Firebase / Firestore
            logger.info(f"[Auth API] /signup: Creating new unverified user '{email}' in database.")
            user_data = db.create_user(
                email=email,
                password_hash=get_password_hash(user_in.password),
                full_name=user_in.full_name,
                is_verified=False,
                auth_provider="email"
            )
            user_id = user_data["id"]
        
        # Generate random 6-digit OTP
        otp_code = "".join(random.choices(string.digits, k=6))
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=5)
        logger.info("OTP generated")
        logger.info(f"[Auth API] /signup: Generated OTP '{otp_code}' for '{email}', expires at {expires_at.isoformat()}")
        
        logger.info(f"[Auth API] /signup: Saving OTP to database for '{email}'...")
        saved = db.save_otp(
            email=email,
            otp_code=otp_code,
            expires_at=expires_at,
            purpose="registration"
        )
        if not saved:
            logger.error(f"[Auth API] /signup database save failure: db.save_otp returned False for '{email}'")
            raise HTTPException(status_code=500, detail="Failed to save registration verification code to database.")
        logger.info("OTP stored")
        logger.info(f"[Auth API] /signup: Successfully saved OTP to database for '{email}'")
        
        # Send OTP via email using asyncio.to_thread to prevent blocking the event loop
        logger.info(f"[Auth API] /signup: Dispatching email_service.send_otp_email via thread pool to '{email}'...")
        email_sent = await asyncio.to_thread(email_service.send_otp_email, email, otp_code)
        if not email_sent:
            raise Exception("Failed to send email via Brevo REST API (email_sent returned False)")
        
        logger.info(f"[Auth API] /signup exit: Verification OTP successfully sent to '{email}'")
        return {"success": True, "message": "OTP sent to your email. Please verify to complete registration."}
    except HTTPException as he:
        logger.error(f"[Auth API] /signup HTTP Exception: {he.status_code} - {he.detail}")
        raise he
    except TimeoutError as te:
        logger.error(f"[Auth API] /signup Email API Timeout: {te}")
        raise HTTPException(
            status_code=400, 
            detail=f"Email gateway timeout: {str(te)}. The Brevo REST API did not respond within the timeout limit."
        )
    except RuntimeError as re:
        err_msg = str(re)
        logger.error(f"[Auth API] /signup Email API Runtime Error: {err_msg}")
        if "401" in err_msg or "unauthorized" in err_msg.lower():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email service authorization failed. Contact administrator."
            )
        elif "429" in err_msg or "rate limit" in err_msg.lower():
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many requests. Please try again later."
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Unable to send OTP email."
            )
    except Exception as e:
        logger.error(f"[Auth API] /signup Unexpected registration error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Internal server error during registration: {str(e)}")


@router.post("/login", response_model=Token)
async def login(user_in: UserLogin, db = Depends(get_db)):
    print(f"[Auth API] login request for email: {user_in.email}")
    try:
        user, access_token = login_user(db, user_in)
        print(f"[Auth API] login success for user id: {user.id}")
        
        created_at_val = None
        if user.created_at:
            if isinstance(user.created_at, datetime):
                created_at_val = user.created_at.isoformat()
            else:
                created_at_val = user.created_at
                
        storage_used_mb = get_user_storage_usage_mb(user.id)
                
        return {
            "access_token": access_token,
            "token_type": "bearer",
            "user": {
                "id": user.id,
                "full_name": user.full_name,
                "email": user.email,
                "is_verified": user.is_verified,
                "profile_image": user.profile_image,
                "created_at": created_at_val,
                "storage_used_mb": storage_used_mb,
                "storage_limit_mb": 20.0
            }
        }
    except Exception as e:
        print(f"Login error: {e}")
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=401, detail=str(e))


@router.post("/google-auth", response_model=Token)
async def google_auth_endpoint(google_in: GoogleAuth, db = Depends(get_db)):
    print(f"[Auth API] google-auth request for email: {google_in.email}")
    try:
        user, access_token = authenticate_google_user(db, google_in)
        print(f"[Auth API] google-auth success for user id: {user.id}")
        
        created_at_val = None
        if user.created_at:
            if isinstance(user.created_at, datetime):
                created_at_val = user.created_at.isoformat()
            else:
                created_at_val = user.created_at
                
        storage_used_mb = get_user_storage_usage_mb(user.id)
                
        return {
            "access_token": access_token,
            "token_type": "bearer",
            "user": {
                "id": user.id,
                "full_name": user.full_name,
                "email": user.email,
                "is_verified": user.is_verified,
                "profile_image": user.profile_image,
                "created_at": created_at_val,
                "storage_used_mb": storage_used_mb,
                "storage_limit_mb": 20.0
            }
        }
    except Exception as e:
        print(f"Google Auth error: {e}")
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/verify-otp")
async def verify_otp(data: OTPVerify, db = Depends(get_db)):
    try:
        email = data.email.lower().strip()
        user_data = db.get_user_by_email(email)
        if not user_data:
            raise HTTPException(status_code=404, detail="User not found")
            
        if user_data.get("is_verified"):
            raise HTTPException(status_code=400, detail="User is already verified")
            
        otp_record = db.get_otp(email)
        if not otp_record or otp_record.get("otp_code") != data.otp:
            raise HTTPException(status_code=400, detail="Invalid OTP")
            
        expires_at_str = otp_record.get("expires_at")
        expires_at = datetime.fromisoformat(expires_at_str) if expires_at_str else None
        if not expires_at or expires_at < datetime.now(timezone.utc):
            raise HTTPException(status_code=400, detail="Expired OTP")
            
        # Verify user and delete OTP
        db.update_user(user_data["id"], {"is_verified": True})
        db.delete_otp_record(email)
        
        # Reload user
        updated_user_data = db.get_user_by_id(user_data["id"])
        user = User(**updated_user_data)
        
        access_token = create_access_token(subject=user.id)
        
        created_at_val = None
        if user.created_at:
            if isinstance(user.created_at, datetime):
                created_at_val = user.created_at.isoformat()
            else:
                created_at_val = user.created_at
                
        storage_used_mb = get_user_storage_usage_mb(user.id)
                
        return {
            "success": True,
            "message": "OTP verified successfully",
            "access_token": access_token,
            "token_type": "bearer",
            "user": {
                "id": user.id,
                "full_name": user.full_name,
                "email": user.email,
                "is_verified": user.is_verified,
                "profile_image": user.profile_image,
                "created_at": created_at_val,
                "storage_used_mb": storage_used_mb,
                "storage_limit_mb": 20.0
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"Verify OTP Error: {e}")
        raise HTTPException(status_code=500, detail="Internal server error during verification")


@router.post("/send-otp")
async def send_otp(data: SendOTP, db = Depends(get_db)):
    email = data.email.lower().strip()
    logger.info(f"[Auth API] /send-otp entry: email='{email}'")
    try:
        user_data = db.get_user_by_email(email)
        if not user_data:
            logger.warning(f"[Auth API] /send-otp user not found: '{email}'")
            raise HTTPException(status_code=404, detail="Email account not found.")
            
        otp_code = "".join(random.choices(string.digits, k=6))
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=5)
        logger.info("OTP generated")
        logger.info(f"[Auth API] /send-otp: Generated OTP '{otp_code}' for '{email}', expires at {expires_at.isoformat()}")
        
        logger.info(f"[Auth API] /send-otp: Saving OTP to database for '{email}'...")
        saved = db.save_otp(
            email=email,
            otp_code=otp_code,
            expires_at=expires_at,
            purpose="registration"
        )
        if not saved:
            logger.error(f"[Auth API] /send-otp database save failure: db.save_otp returned False for '{email}'")
            raise HTTPException(status_code=500, detail="Failed to save verification code to database.")
        logger.info("OTP stored")
        logger.info(f"[Auth API] /send-otp: Successfully saved OTP to database for '{email}'")
        
        logger.info(f"[Auth API] /send-otp: Dispatching email_service.send_otp_email via thread pool to '{email}'...")
        email_sent = await asyncio.to_thread(email_service.send_otp_email, email, otp_code)
        if not email_sent:
            raise Exception("Failed to send email via Brevo REST API (email_sent returned False)")
            
        logger.info(f"[Auth API] /send-otp exit: OTP successfully resent to '{email}'")
        return {"success": True, "message": "OTP resent successfully"}
    except HTTPException as he:
        logger.error(f"[Auth API] /send-otp HTTP Exception: {he.status_code} - {he.detail}")
        raise he
    except TimeoutError as te:
        logger.error(f"[Auth API] /send-otp Email API Timeout: {te}")
        raise HTTPException(
            status_code=400, 
            detail=f"Email gateway timeout: {str(te)}. The Brevo REST API did not respond within the timeout limit."
        )
    except RuntimeError as re:
        err_msg = str(re)
        logger.error(f"[Auth API] /send-otp Email API Runtime Error: {err_msg}")
        if "401" in err_msg or "unauthorized" in err_msg.lower():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email service authorization failed. Contact administrator."
            )
        elif "429" in err_msg or "rate limit" in err_msg.lower():
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many requests. Please try again later."
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Unable to send OTP email."
            )
    except Exception as e:
        logger.error(f"[Auth API] /send-otp Unexpected error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Internal server error while resending OTP: {str(e)}")


def send_email_in_background(email: str, otp_code: str):
    import time
    start_time = time.time()
    logger.info(f"[Background Task] Email sending started for '{email}'")
    try:
        email_sent = email_service.send_password_reset_email(email, otp_code)
        duration = time.time() - start_time
        if email_sent:
            logger.info(f"[Background Task] Email sent successfully to '{email}' in {duration:.4f} seconds")
        else:
            logger.error(f"[Background Task] Failed to send email to '{email}' in {duration:.4f} seconds")
    except Exception as e:
        duration = time.time() - start_time
        logger.error(f"[Background Task] Exception during email sending to '{email}' after {duration:.4f} seconds: {str(e)}", exc_info=True)


@router.post("/send-reset-otp")
async def send_reset_otp(data: ForgotPassword, db = Depends(get_db)):
    import time
    start_time = time.time()
    email = data.email.lower().strip()
    logger.info(f"[SEND_RESET_OTP] Request received for {email}")
    
    async def process_request():
        user_data = db.get_user_by_email(email)
        if not user_data:
            logger.warning(f"[SEND_RESET_OTP] Email validation failed: No account found with email '{email}'")
            raise HTTPException(status_code=404, detail="Email account not found.")
        
        logger.info(f"[SEND_RESET_OTP] Email validated")
        
        # Generate OTP
        otp_code = "".join(random.choices(string.digits, k=6))
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=5)
        logger.info(f"[SEND_RESET_OTP] OTP generated")
        
        saved = db.save_otp(
            email=email,
            otp_code=otp_code,
            expires_at=expires_at,
            purpose="password_reset"
        )
        if not saved:
            logger.error(f"[SEND_RESET_OTP] Database save failure: db.save_otp returned False for '{email}'")
            raise HTTPException(status_code=500, detail="Failed to save password reset code to database.")
        logger.info(f"[SEND_RESET_OTP] OTP stored")
        
        logger.info(f"[SEND_RESET_OTP] Dispatching email_service.send_password_reset_email via thread pool to '{email}'...")
        email_sent = await asyncio.to_thread(email_service.send_password_reset_email, email, otp_code)
        if not email_sent:
            raise Exception("Failed to send email via Brevo REST API (email_sent returned False)")
            
        return {"success": True, "message": "Verification code sent to your email."}

    try:
        # Enforce maximum timeout of 10 seconds
        res = await asyncio.wait_for(process_request(), timeout=10.0)
        duration = time.time() - start_time
        logger.info(f"[SEND_RESET_OTP] Response returned immediately in {duration:.4f} seconds")
        return res
    except asyncio.TimeoutError:
        duration = time.time() - start_time
        logger.error(f"[SEND_RESET_OTP] Request timed out after {duration:.4f} seconds")
        raise HTTPException(
            status_code=504,
            detail="The request timed out. Please try again."
        )
    except HTTPException as he:
        duration = time.time() - start_time
        logger.error(f"[SEND_RESET_OTP] HTTP Exception in {duration:.4f} seconds: {he.status_code} - {he.detail}")
        raise he
    except TimeoutError as te:
        logger.error(f"[SEND_RESET_OTP] Email API Timeout: {te}")
        raise HTTPException(
            status_code=400, 
            detail=f"Email gateway timeout: {str(te)}. The Brevo REST API did not respond within the timeout limit."
        )
    except RuntimeError as re:
        err_msg = str(re)
        logger.error(f"[SEND_RESET_OTP] Email API Runtime Error: {err_msg}")
        if "401" in err_msg or "unauthorized" in err_msg.lower():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email service authorization failed. Contact administrator."
            )
        elif "429" in err_msg or "rate limit" in err_msg.lower():
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many requests. Please try again later."
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Unable to send OTP email."
            )
    except Exception as e:
        duration = time.time() - start_time
        logger.error(f"[SEND_RESET_OTP] Exception thrown in {duration:.4f} seconds: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Internal server error while generating reset OTP: {str(e)}")


@router.post("/verify-reset-otp")
async def verify_reset_otp(data: OTPVerify, db = Depends(get_db)):
    email = data.email.lower().strip()
    logger.info(f"[Auth API] /verify-reset-otp entry: email='{email}', otp='{data.otp}'")
    try:
        user_data = db.get_user_by_email(email)
        if not user_data:
            logger.warning(f"[Auth API] /verify-reset-otp user not found: '{email}'")
            raise HTTPException(status_code=404, detail="User not found")
            
        otp_record = db.get_otp(email)
        if not otp_record or otp_record.get("otp_code") != data.otp or otp_record.get("purpose") != "password_reset":
            logger.warning(f"[Auth API] /verify-reset-otp validation failure: invalid OTP/purpose for '{email}'")
            raise HTTPException(status_code=400, detail="Invalid OTP")
            
        expires_at_str = otp_record.get("expires_at")
        expires_at = datetime.fromisoformat(expires_at_str) if expires_at_str else None
        if not expires_at or expires_at < datetime.now(timezone.utc):
            logger.warning(f"[Auth API] /verify-reset-otp validation failure: expired OTP for '{email}'")
            raise HTTPException(status_code=400, detail="Expired OTP")
        
        logger.info(f"[Auth API] /verify-reset-otp exit: OTP successfully verified for '{email}'")
        # Do NOT clear OTP yet, they need it for the final reset-password step!
        return {"success": True, "message": "Code verified successfully.", "email": email, "otp": data.otp}
    except HTTPException as he:
        raise he
    except Exception as e:
        logger.error(f"[Auth API] /verify-reset-otp Unexpected error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Internal server error during verification: {str(e)}")


@router.post("/reset-password")
async def reset_password(data: ResetPassword, db = Depends(get_db)):
    email = data.email.lower().strip()
    logger.info(f"[Auth API] /reset-password entry: email='{email}'")
    try:
        user_data = db.get_user_by_email(email)
        if not user_data:
            logger.warning(f"[Auth API] /reset-password user not found: '{email}'")
            raise HTTPException(status_code=404, detail="User not found.")
            
        otp_record = db.get_otp(email)
        # Re-verify the OTP one last time
        if not otp_record or otp_record.get("otp_code") != data.otp or otp_record.get("purpose") != "password_reset":
            logger.warning(f"[Auth API] /reset-password validation failure: invalid or expired OTP for '{email}'")
            raise HTTPException(status_code=400, detail="Verification expired or invalid. Please request a new code.")
            
        expires_at_str = otp_record.get("expires_at")
        expires_at = datetime.fromisoformat(expires_at_str) if expires_at_str else None
        if not expires_at or expires_at < datetime.now(timezone.utc):
            logger.warning(f"[Auth API] /reset-password validation failure: expired OTP for '{email}'")
            raise HTTPException(status_code=400, detail="OTP Expired")
        
        # Update Password and delete OTP
        new_hash = get_password_hash(data.new_password)
        logger.info(f"[Auth API] /reset-password: Updating password in database for user id '{user_data['id']}'...")
        db.update_user_password(user_data["id"], new_hash)
        logger.info(f"[Auth API] /reset-password: Deleting OTP verification record for '{email}'...")
        db.delete_otp_record(email)
        
        logger.info(f"[Auth API] /reset-password exit: Password successfully updated for '{email}'")
        return {"success": True, "message": "Password updated successfully. You can now sign in."}
    except HTTPException as he:
        raise he
    except Exception as e:
        logger.error(f"[Auth API] /reset-password Unexpected error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Internal server error during password reset: {str(e)}")


@router.post("/change-password")
async def change_password_endpoint(
    data: ChangePassword, 
    db = Depends(get_db), 
    current_user: User = Depends(get_current_user)
):
    return change_pwd_service(db, current_user.id, data)


@router.get("/me")
async def get_me(current_user: User = Depends(get_current_user)):
    created_at_val = None
    if current_user.created_at:
        if isinstance(current_user.created_at, datetime):
            created_at_val = current_user.created_at.isoformat()
        else:
            created_at_val = current_user.created_at
            
    storage_used_mb = get_user_storage_usage_mb(current_user.id)
            
    return {
        "id": current_user.id,
        "full_name": current_user.full_name,
        "email": current_user.email,
        "is_verified": current_user.is_verified,
        "profile_image": current_user.profile_image,
        "created_at": created_at_val,
        "storage_used_mb": storage_used_mb,
        "storage_limit_mb": 20.0
    }


@router.get("/health")
async def health_check():
    return {"status": "ok", "message": "Auth service is healthy"}


@router.post("/logout")
async def logout_endpoint():
    return {"success": True, "message": "Logged out successfully"}


@router.post("/refresh-token")
async def refresh_token_endpoint():
    return {"success": True, "message": "Token refreshed successfully", "data": {"access_token": "dummy_token"}}
