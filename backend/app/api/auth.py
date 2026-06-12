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
async def signup(user_in: UserCreate, background_tasks: BackgroundTasks, db = Depends(get_db)):
    email = user_in.email.lower().strip()
    logger.info(f"[Auth API] /signup entry: email='{email}', name='{user_in.full_name}'")
    try:
        # Check if user already exists in Firestore
        user_data = db.get_user_by_email(email)
        if user_data and user_data.get("is_verified"):
            logger.warning(f"[Auth API] /signup conflict: User with email '{email}' already exists and is verified.")
            raise HTTPException(status_code=400, detail="User with this email already exists")
        
        # Generate random 6-digit OTP
        otp_code = "".join(random.choices(string.digits, k=6))
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=5)
        logger.info("OTP generated")
        logger.info(f"[Auth API] /signup: Generated OTP '{otp_code}' for '{email}', expires at {expires_at.isoformat()}")
        
        # Store registration data temporarily in the OTP verification record
        registration_data = {
            "full_name": user_in.full_name,
            "password_hash": get_password_hash(user_in.password)
        }
        
        # Do not store plain OTP values
        import hashlib
        hashed_otp = hashlib.sha256(otp_code.encode()).hexdigest()
        
        logger.info(f"[Auth API] /signup: Saving OTP to database for '{email}'...")
        saved = db.save_otp(
            email=email,
            otp_code=hashed_otp,
            expires_at=expires_at,
            purpose="registration",
            registration_data=registration_data
        )
        if not saved:
            logger.error(f"[Auth API] /signup database save failure: db.save_otp returned False for '{email}'")
            raise HTTPException(status_code=500, detail="Failed to save registration verification code to database.")
        logger.info("OTP stored")
        logger.info(f"[Auth API] /signup: Successfully saved OTP to database for '{email}'")
        
        # Send OTP via email in the background
        logger.info(f"[Auth API] /signup: Dispatching email_service.send_otp_email in background to '{email}'...")
        background_tasks.add_task(send_otp_in_background, email, otp_code)
        return {"success": True, "message": "OTP sent to your email. Please verify to complete registration."}
    except HTTPException as he:
        logger.error(f"[Auth API] /signup HTTP Exception: {he.status_code} - {he.detail}")
        raise he
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
                
        try:
            storage_used_mb = await asyncio.wait_for(
                asyncio.to_thread(get_user_storage_usage_mb, user.id),
                timeout=2.0
            )
        except Exception as e:
            print(f"Timeout/Error fetching storage usage for user {user.id} in login: {e}")
            storage_used_mb = 0.0
                
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
                
        try:
            storage_used_mb = await asyncio.wait_for(
                asyncio.to_thread(get_user_storage_usage_mb, user.id),
                timeout=2.0
            )
        except Exception as e:
            print(f"Timeout/Error fetching storage usage for user {user.id} in google-auth: {e}")
            storage_used_mb = 0.0
                
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
        otp_record = db.get_otp(email)
        if not otp_record:
            raise HTTPException(status_code=400, detail="No verification code found. Please request a new one.")
            
        # Check maximum verification attempts (5 attempts)
        attempts = otp_record.get("attempts", 0) + 1
        # Update attempts in the database
        db.db.collection("otp_verifications").document(email).update({"attempts": attempts})
        
        if attempts > 5:
            # Delete OTP record for security
            db.delete_otp_record(email)
            raise HTTPException(status_code=400, detail="Maximum verification attempts exceeded. Please sign up again.")
            
        # Verify code matches hashed OTP
        import hashlib
        hashed_input = hashlib.sha256(data.otp.encode()).hexdigest()
        if otp_record.get("otp_code") != hashed_input:
            raise HTTPException(status_code=400, detail=f"Invalid verification code. Attempt {attempts} of 5.")
            
        expires_at_str = otp_record.get("expires_at")
        expires_at = datetime.fromisoformat(expires_at_str) if expires_at_str else None
        if not expires_at or expires_at < datetime.now(timezone.utc):
            raise HTTPException(status_code=400, detail="Verification code has expired. Please request a new one.")
            
        # Check purpose
        purpose = otp_record.get("purpose")
        
        if purpose == "registration":
            # ONLY create the user now
            import json
            reg_data_str = otp_record.get("registration_data")
            if not reg_data_str:
                raise HTTPException(status_code=400, detail="Registration data not found. Please sign up again.")
            reg_data = json.loads(reg_data_str)
            
            # Create user and mark is_verified = True
            user_data = db.create_user(
                email=email,
                password_hash=reg_data["password_hash"],
                full_name=reg_data["full_name"],
                is_verified=True,
                auth_provider="email"
            )
        else:
            # For password reset or other purposes, load existing user
            user_data = db.get_user_by_email(email)
            if not user_data:
                raise HTTPException(status_code=404, detail="User not found")
        
        # Remove OTP after successful verification
        db.delete_otp_record(email)
        
        # Reload user
        user = User(**user_data)
        
        access_token = create_access_token(subject=user.id)
        
        created_at_val = None
        if user.created_at:
            if isinstance(user.created_at, datetime):
                created_at_val = user.created_at.isoformat()
            else:
                created_at_val = user.created_at
                
        try:
            storage_used_mb = await asyncio.wait_for(
                asyncio.to_thread(get_user_storage_usage_mb, user.id),
                timeout=2.0
            )
        except Exception as e:
            print(f"Timeout/Error fetching storage usage for user {user.id} in verify-otp: {e}")
            storage_used_mb = 0.0
                
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
async def send_otp(data: SendOTP, background_tasks: BackgroundTasks, db = Depends(get_db)):
    email = data.email.lower().strip()
    logger.info(f"[Auth API] /send-otp entry: email='{email}'")
    try:
        # Check if there is an active registration OTP record or existing user
        otp_record = db.get_otp(email)
        user_data = db.get_user_by_email(email)
        
        if not user_data and not otp_record:
            logger.warning(f"[Auth API] /send-otp user not found: '{email}'")
            raise HTTPException(status_code=404, detail="Email account not found.")
            
        otp_code = "".join(random.choices(string.digits, k=6))
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=5)
        logger.info("OTP generated")
        logger.info(f"[Auth API] /send-otp: Generated OTP '{otp_code}' for '{email}', expires at {expires_at.isoformat()}")
        
        import hashlib
        hashed_otp = hashlib.sha256(otp_code.encode()).hexdigest()
        
        # Preserve existing registration data if any
        reg_data = None
        if otp_record and otp_record.get("registration_data"):
            import json
            try:
                reg_data = json.loads(otp_record["registration_data"])
            except Exception:
                pass
                
        logger.info(f"[Auth API] /send-otp: Saving OTP to database for '{email}'...")
        saved = db.save_otp(
            email=email,
            otp_code=hashed_otp,
            expires_at=expires_at,
            purpose=otp_record.get("purpose", "registration") if otp_record else "registration",
            registration_data=reg_data
        )
        if not saved:
            logger.error(f"[Auth API] /send-otp database save failure: db.save_otp returned False for '{email}'")
            raise HTTPException(status_code=500, detail="Failed to save verification code to database.")
        logger.info("OTP stored")
        logger.info(f"[Auth API] /send-otp: Successfully saved OTP to database for '{email}'")
        
        # Send OTP via email in the background
        logger.info(f"[Auth API] /send-otp: Dispatching email_service.send_otp_email in background to '{email}'...")
        background_tasks.add_task(send_otp_in_background, email, otp_code)
        return {"success": True, "message": "OTP resent successfully."}
    except HTTPException as he:
        logger.error(f"[Auth API] /send-otp HTTP Exception: {he.status_code} - {he.detail}")
        raise he
    except Exception as e:
        logger.error(f"[Auth API] /send-otp Unexpected error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Internal server error while resending OTP: {str(e)}")


def send_otp_in_background(email: str, otp_code: str):
    import time
    start_time = time.time()
    logger.info(f"[Background Task] OTP email sending started for '{email}'")
    try:
        email_sent = email_service.send_otp_email(email, otp_code)
        duration = time.time() - start_time
        if email_sent:
            logger.info(f"[Background Task] OTP email sent successfully to '{email}' in {duration:.4f} seconds")
        else:
            logger.error(f"[Background Task] Failed to send OTP email to '{email}' in {duration:.4f} seconds")
    except Exception as e:
        duration = time.time() - start_time
        logger.error(f"[Background Task] Exception during OTP email sending to '{email}' after {duration:.4f} seconds: {str(e)}", exc_info=True)


def send_email_in_background(email: str, otp_code: str):
    import time
    start_time = time.time()
    logger.info(f"[Background Task] Password reset email sending started for '{email}'")
    try:
        email_sent = email_service.send_password_reset_email(email, otp_code)
        duration = time.time() - start_time
        if email_sent:
            logger.info(f"[Background Task] Password reset email sent successfully to '{email}' in {duration:.4f} seconds")
        else:
            logger.error(f"[Background Task] Failed to send password reset email to '{email}' in {duration:.4f} seconds")
    except Exception as e:
        duration = time.time() - start_time
        logger.error(f"[Background Task] Exception during password reset email sending to '{email}' after {duration:.4f} seconds: {str(e)}", exc_info=True)


@router.post("/send-reset-otp")
async def send_reset_otp(data: ForgotPassword, background_tasks: BackgroundTasks, db = Depends(get_db)):
    import time
    start_time = time.time()
    email = data.email.lower().strip()
    logger.info(f"[SEND_RESET_OTP] Request received for {email}")
    logger.info(f"[SEND_RESET_OTP] Email checked: '{email}'")
    
    try:
        user_data = db.get_user_by_email(email)
        if not user_data:
            logger.warning(f"[SEND_RESET_OTP] User not found: Email '{email}' is not registered in the database.")
            logger.info(f"[SEND_RESET_OTP] OTP not sent: User for email '{email}' is not found.")
            raise HTTPException(status_code=404, detail="Email not registered. Please create an account.")
        
        logger.info(f"[SEND_RESET_OTP] User found: Email '{email}' exists.")
        
        # Generate OTP
        otp_code = "".join(random.choices(string.digits, k=6))
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=5)
        logger.info(f"[SEND_RESET_OTP] OTP generated for '{email}'")
        
        saved = db.save_otp(
            email=email,
            otp_code=otp_code,
            expires_at=expires_at,
            purpose="password_reset"
        )
        if not saved:
            logger.error(f"[SEND_RESET_OTP] Database save failure: db.save_otp returned False for '{email}'")
            logger.info(f"[SEND_RESET_OTP] OTP not sent: Failed to save to database for '{email}'.")
            raise HTTPException(status_code=500, detail="Failed to save password reset code to database.")
        logger.info(f"[SEND_RESET_OTP] OTP stored in database")
        
        # Send Password Reset OTP via email in the background
        logger.info(f"[SEND_RESET_OTP] Dispatching email_service.send_password_reset_email in background to '{email}'...")
        background_tasks.add_task(send_email_in_background, email, otp_code)
        logger.info(f"[SEND_RESET_OTP] OTP sent: Password reset OTP dispatched for '{email}'.")
        return {"success": True, "message": "Verification code sent to your email."}
            
    except HTTPException as he:
        raise he
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
        if not otp_record:
            raise HTTPException(status_code=400, detail="No verification code found. Please request a new one.")
            
        # Check attempts
        attempts = otp_record.get("attempts", 0) + 1
        db.db.collection("otp_verifications").document(email).update({"attempts": attempts})
        if attempts > 5:
            db.delete_otp_record(email)
            raise HTTPException(status_code=400, detail="Maximum verification attempts exceeded. Please try again.")
            
        import hashlib
        hashed_input = hashlib.sha256(data.otp.encode()).hexdigest()
        if otp_record.get("otp_code") != hashed_input or otp_record.get("purpose") != "password_reset":
            logger.warning(f"[Auth API] /verify-reset-otp validation failure: invalid OTP/purpose for '{email}'")
            raise HTTPException(status_code=400, detail=f"Invalid verification code. Attempt {attempts} of 5.")
            
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
        if not otp_record:
            raise HTTPException(status_code=400, detail="Verification expired or invalid. Please request a new code.")
            
        # Re-verify the OTP one last time
        import hashlib
        hashed_input = hashlib.sha256(data.otp.encode()).hexdigest()
        if otp_record.get("otp_code") != hashed_input or otp_record.get("purpose") != "password_reset":
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
