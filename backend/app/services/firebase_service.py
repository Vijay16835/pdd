import os
import logging
from datetime import datetime, timezone, timedelta
from typing import List, Dict, Any, Optional
import firebase_admin
from firebase_admin import credentials, firestore, auth, storage
from app.core.config import settings

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# psycopg2 connection pool — one pool for the lifetime of the process.
# Replaces per-call psycopg2.connect() which opened a new TCP socket on
# every database operation.
# ---------------------------------------------------------------------------
_pg_pool = None


class _PgConnWrapper:
    """
    Transparent proxy around a psycopg2 connection checked out from the pool.
    Overrides close() to call pool.putconn() so every existing conn.close()
    call site automatically returns the connection without any further changes.
    """
    __slots__ = ("_conn", "_pool")

    def __init__(self, conn, pool):
        object.__setattr__(self, "_conn", conn)
        object.__setattr__(self, "_pool", pool)

    def __getattr__(self, name):
        return getattr(object.__getattribute__(self, "_conn"), name)

    def __setattr__(self, name, value):
        setattr(object.__getattribute__(self, "_conn"), name, value)

    def close(self):
        conn = object.__getattribute__(self, "_conn")
        pool = object.__getattribute__(self, "_pool")
        try:
            pool.putconn(conn)
        except Exception:
            try:
                conn.close()
            except Exception:
                pass

    def cursor(self, *args, **kwargs):
        return object.__getattribute__(self, "_conn").cursor(*args, **kwargs)

    def commit(self):
        return object.__getattribute__(self, "_conn").commit()

    def rollback(self):
        return object.__getattribute__(self, "_conn").rollback()

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()


def _get_pg_pool():
    """Lazily initialise and return the shared ThreadedConnectionPool."""
    global _pg_pool
    if _pg_pool is None:
        try:
            import psycopg2.pool
            import urllib.parse
            db_url = os.getenv("DATABASE_URL") or settings.DATABASE_URL
            if "Tvijay@1098" in db_url:
                db_url = db_url.replace("Tvijay@1098", "Tvijay%401098")
            
            # Auto-migrate direct connection to pooler connection string if needed
            try:
                parsed = urllib.parse.urlparse(db_url)
                if parsed.hostname and parsed.hostname.endswith(".supabase.co"):
                    logger.info(f"[Database Service] Direct Supabase connection detected: {parsed.hostname}. Migrating to pooler connection string...")
                    project_id = parsed.hostname.replace("db.", "").replace(".supabase.co", "")
                    region = "ap-south-1"  # Region based on configuration
                    pooler_host = f"aws-1-{region}.pooler.supabase.com"
                    pooler_port = 6543
                    
                    username = parsed.username
                    if username and not username.endswith(f".{project_id}"):
                        username = f"{username}.{project_id}"
                        
                    password = parsed.password or ""
                    netloc = f"{username}:{password}@{pooler_host}:{pooler_port}"
                    db_url = urllib.parse.urlunparse((
                        parsed.scheme,
                        netloc,
                        parsed.path,
                        parsed.params,
                        parsed.query,
                        parsed.fragment
                    ))
                    logger.info(f"[Database Service] Migrated DATABASE_URL to pooler format: postgresql://{username}:****@{pooler_host}:{pooler_port}{parsed.path}")
            except Exception as parse_err:
                logger.warning(f"[Database Service] Failed to parse/migrate DATABASE_URL: {parse_err}")
                
            _pg_pool = psycopg2.pool.ThreadedConnectionPool(2, 10, dsn=db_url)
            logger.info("psycopg2 ThreadedConnectionPool initialised (min=2, max=10).")
        except Exception as e:
            logger.error(f"Failed to create psycopg2 pool: {e}")
    return _pg_pool

# Initialize Firebase Admin SDK
cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
if not cred_path:
    local_default = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "firebase_credentials.json")
    if os.path.exists(local_default):
        cred_path = local_default
    else:
        logger.error("FIREBASE_CREDENTIALS_PATH environment variable is missing!")
        raise RuntimeError("FIREBASE_CREDENTIALS_PATH environment variable is missing!")

if not os.path.exists(cred_path):
    local_fallback = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "firebase_credentials.json")
    if os.path.exists(local_fallback):
        logger.warning(f"Configured FIREBASE_CREDENTIALS_PATH '{cred_path}' not found, falling back to local file: {local_fallback}")
        cred_path = local_fallback
    else:
        logger.error(f"Firebase credentials file not found at path: {cred_path}")
        raise FileNotFoundError(f"Firebase credentials file not found at path: {cred_path}")

try:
    cred = credentials.Certificate(cred_path)
    if not firebase_admin._apps:
        bucket_name = os.getenv("FIREBASE_STORAGE_BUCKET")
        options = {'storageBucket': bucket_name} if bucket_name else {}
        firebase_admin.initialize_app(cred, options)
        logger.info(f"Firebase initialized with credentials file at {cred_path}.")
except Exception as e:
    logger.error(f"Error during Firebase initialization: {e}")
    raise e


class FirebaseService:
    def __init__(self):
        self._db = None
        self._bucket = None

    def check_connectivity(self) -> bool:
        """Verify database connectivity by acquiring a connection and executing a simple query."""
        logger.info("[Database Service] Running database connectivity startup check...")
        conn = None
        try:
            conn = self._get_pg_conn()
            if not conn:
                logger.error("[Database Service] Database connection check failed: Could not acquire connection from pool.")
                return False
            cur = conn.cursor()
            cur.execute("SELECT 1;")
            result = cur.fetchone()
            
            # Ensure users and documents schema is migrated
            try:
                cur.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS date_of_birth VARCHAR(50);")
                cur.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS age INTEGER;")
                cur.execute("ALTER TABLE documents ADD COLUMN IF NOT EXISTS error_message TEXT;")
                conn.commit()
                logger.info("[Database Service] PostgreSQL schema migration complete.")
            except Exception as schema_err:
                logger.warning(f"[Database Service] Non-blocking schema migration warning: {schema_err}")
                conn.rollback()
                
            cur.close()
            conn.close()
            if result and result[0] == 1:
                logger.info("[Database Service] Database connectivity verified successfully (SELECT 1 returned 1).")
                return True
            else:
                logger.error(f"[Database Service] Database connection check failed: Unexpected query result {result}")
                return False
        except Exception as e:
            logger.critical(f"[Database Service] Database connection check failed with exception: {type(e).__name__}: {str(e)}", exc_info=True)
            if conn:
                try:
                    conn.close()
                except Exception:
                    pass
            return False

    def _get_pg_conn(self):
        """Check out a wrapped connection from the shared pool."""
        try:
            pool = _get_pg_pool()
            if pool:
                return _PgConnWrapper(pool.getconn(), pool)
        except Exception as e:
            logger.error(f"Failed to get connection from pool: {e}")
        return None

    def _release_pg_conn(self, conn):
        """Explicit release — conn.close() on the wrapper also works."""
        if conn:
            conn.close()

    @property
    def db(self):
        if self._db is None:
            self._db = firestore.client()
        return self._db

    @property
    def bucket(self):
        if self._bucket is None:
            try:
                self._bucket = storage.bucket()
            except Exception as e:
                logger.error(f"Failed to get Firebase storage bucket: {e}")
                self._bucket = None
        return self._bucket

    # -------------------------------------------------------------
    # User Operations
    # -------------------------------------------------------------
    def get_user_by_firebase_uid(self, firebase_uid: str) -> Optional[Dict[str, Any]]:
        """Fetch user by Firebase UID from Firestore users collection."""
        try:
            # The doc ID is the Firebase UID, so direct lookup is fastest
            doc = self.db.collection("users").document(firebase_uid).get()
            if doc.exists:
                data = doc.to_dict()
                data["id"] = doc.id
                return data
            # Fallback: query by firebase_uid field (for legacy records)
            query = self.db.collection("users").where("firebase_uid", "==", firebase_uid).limit(1).stream()
            for doc in query:
                data = doc.to_dict()
                data["id"] = doc.id
                return data
            return None
        except Exception as e:
            logger.error(f"Error getting user by firebase_uid {firebase_uid}: {e}")
            return None

    def get_user_by_email(self, email: str) -> Optional[Dict[str, Any]]:
        """Fetch user by email from Firestore users collection."""
        try:
            users_ref = self.db.collection("users")
            query = users_ref.where("email", "==", email.lower().strip()).limit(1).stream()
            for doc in query:
                data = doc.to_dict()
                data["id"] = doc.id  # Set Firestore doc ID as user ID
                return data
            return None
        except Exception as e:
            logger.error(f"Error getting user by email {email}: {e}")
            return None

    def get_user_by_id(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Fetch user by ID from Firestore users collection."""
        try:
            doc = self.db.collection("users").document(user_id).get()
            if doc.exists:
                data = doc.to_dict()
                data["id"] = doc.id
                return data
            return None
        except Exception as e:
            logger.error(f"Error getting user by ID {user_id}: {e}")
            return None

    def create_user(self, email: str, password_hash: str, full_name: str, is_verified: bool = False, auth_provider: str = "email", firebase_uid: str = None, date_of_birth: str = None, age: int = None) -> Dict[str, Any]:
        """Create user in Firebase Auth and Firestore users collection."""
        email_clean = email.lower().strip()
        user_id = firebase_uid
        
        if not user_id:
            # 1. Create in Firebase Auth
            try:
                # Check if user already exists in Auth
                try:
                    user_record = auth.get_user_by_email(email_clean)
                    user_id = user_record.uid
                except auth.UserNotFoundError:
                    user_record = auth.create_user(
                        email=email_clean,
                        display_name=full_name,
                        email_verified=is_verified
                    )
                    user_id = user_record.uid
            except Exception as e:
                # Fallback if Firebase Auth is offline or mocking: generate a unique string
                logger.warning(f"Firebase Auth user creation skipped/failed, generating local ID: {e}")
                import uuid
                user_id = f"user_{uuid.uuid4().hex[:12]}"

        # 2. Save in Firestore users collection
        user_data = {
            "id": user_id,
            "firebase_uid": user_id,          # Explicit field for querying
            "email": email_clean,
            "full_name": full_name,
            "hashed_password": password_hash,
            "is_verified": is_verified,
            "auth_provider": auth_provider,
            "profile_image": None,
            "date_of_birth": date_of_birth,
            "age": age,
            "created_at": datetime.now(timezone.utc).isoformat(),
            "updated_at": datetime.now(timezone.utc).isoformat(),
            "settings": {
                "is_dark_mode": True,
                "notifications_enabled": True,
                "selected_language": "English",
                "ai_model": "LexGuard AI Engine v2.0",
                "analysis_depth": "Comprehensive",
                "voice_speed": 1.0,
                "voice_response_enabled": False
            }
        }
        
        # 2.5 Dual-write to Supabase PostgreSQL
        conn = None
        try:
            conn = self._get_pg_conn()
            if conn:
                cur = conn.cursor()
                try:
                    cur.execute("""
                        INSERT INTO users (id, full_name, email, hashed_password, is_verified, auth_provider, date_of_birth, age)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                        ON CONFLICT (email) DO UPDATE SET 
                            id = EXCLUDED.id,
                            hashed_password = EXCLUDED.hashed_password,
                            full_name = EXCLUDED.full_name,
                            date_of_birth = EXCLUDED.date_of_birth,
                            age = EXCLUDED.age
                    """, (user_id, full_name, email_clean, password_hash, is_verified, auth_provider, date_of_birth, age))
                    conn.commit()
                finally:
                    cur.close()
                logger.info(f"Successfully dual-written user {user_id} to Supabase PostgreSQL")
            else:
                logger.error(f"Failed to get PostgreSQL connection for dual-write user {user_id}")
        except Exception as e:
            logger.error(f"Failed to insert user {user_id} into PostgreSQL: {e}")
        finally:
            if conn:
                conn.close()
            
        self.db.collection("users").document(user_id).set(user_data)
        return user_data

    def update_user(self, user_id: str, updates: Dict[str, Any]) -> bool:
        """Update user profile in Firestore."""
        try:
            updates["updated_at"] = datetime.now(timezone.utc).isoformat()
            self.db.collection("users").document(user_id).update(updates)
            
            # Update PostgreSQL for dual-write consistency
            conn = None
            try:
                conn = self._get_pg_conn()
                if conn:
                    cur = conn.cursor()
                    try:
                        set_clauses = []
                        params = []
                        mapping = {
                            "full_name": "full_name",
                            "email": "email",
                            "is_verified": "is_verified",
                            "hashed_password": "hashed_password",
                            "auth_provider": "auth_provider",
                            "profile_image": "profile_image"
                        }
                        for k, v in updates.items():
                            if k in mapping:
                                set_clauses.append(f"{mapping[k]} = %s")
                                params.append(v)
                        if set_clauses:
                            set_clauses.append("updated_at = %s")
                            params.append(datetime.now(timezone.utc))
                            params.append(user_id)
                            query = f"UPDATE users SET {', '.join(set_clauses)} WHERE id = %s"
                            cur.execute(query, tuple(params))
                            conn.commit()
                            logger.info(f"Successfully dual-written user update for {user_id} to Supabase PostgreSQL")
                    finally:
                        cur.close()
            except Exception as pg_err:
                logger.error(f"Failed to update user {user_id} in PostgreSQL: {pg_err}")
            finally:
                if conn:
                    conn.close()
            
            # If full_name or email is updated, reflect in Firebase Auth if available
            try:
                auth_updates = {}
                if "full_name" in updates:
                    auth_updates["display_name"] = updates["full_name"]
                if "is_verified" in updates:
                    auth_updates["email_verified"] = updates["is_verified"]
                if auth_updates:
                    auth.update_user(user_id, **auth_updates)
            except Exception as auth_err:
                logger.debug(f"Auth sync skipped: {auth_err}")
                
            return True
        except Exception as e:
            logger.error(f"Error updating user {user_id}: {e}")
            return False

    def update_user_password(self, user_id: str, new_password_hash: str) -> bool:
        """Update user password hash in Firestore, Auth, and Supabase PostgreSQL."""
        try:
            # 1. Update Firestore
            self.db.collection("users").document(user_id).update({
                "hashed_password": new_password_hash,
                "updated_at": datetime.now(timezone.utc).isoformat()
            })
            
            # 2. Update PostgreSQL for dual-write consistency
            conn = None
            try:
                conn = self._get_pg_conn()
                if conn:
                    cur = conn.cursor()
                    try:
                        cur.execute("""
                            UPDATE users 
                            SET hashed_password = %s, updated_at = %s 
                            WHERE id = %s
                        """, (new_password_hash, datetime.now(timezone.utc), user_id))
                        conn.commit()
                    finally:
                        cur.close()
                    logger.info(f"Successfully dual-written password update for user {user_id} to Supabase PostgreSQL")
                else:
                    logger.error(f"Failed to get PostgreSQL connection for dual-write password update for user {user_id}")
            except Exception as pg_err:
                logger.error(f"Failed to update password for user {user_id} in PostgreSQL: {pg_err}")
            finally:
                if conn:
                    conn.close()
                
            return True
        except Exception as e:
            logger.error(f"Error updating password for {user_id}: {e}")
            return False

    # -------------------------------------------------------------
    # OTP operations
    # -------------------------------------------------------------
    def save_otp(self, email: str, otp_code: str, expires_at: datetime, purpose: str = "registration", registration_data: dict = None) -> bool:
        """Save OTP verification code to Firestore."""
        try:
            import json
            otp_data = {
                "email": email.lower().strip(),
                "otp_code": otp_code,
                "expires_at": expires_at.isoformat(),
                "is_verified": False,
                "purpose": purpose,
                "attempts": 0,
                "registration_data": json.dumps(registration_data) if registration_data else None,
                "created_at": datetime.now(timezone.utc).isoformat()
            }
            self.db.collection("otp_verifications").document(email.lower().strip()).set(otp_data)
            return True
        except Exception as e:
            logger.error(f"Error saving OTP for {email}: {e}")
            return False

    def get_otp(self, email: str) -> Optional[Dict[str, Any]]:
        """Fetch OTP verification record from Firestore."""
        try:
            doc = self.db.collection("otp_verifications").document(email.lower().strip()).get()
            if doc.exists:
                return doc.to_dict()
            return None
        except Exception as e:
            logger.error(f"Error getting OTP for {email}: {e}")
            return None

    def verify_otp_record(self, email: str) -> bool:
        """Mark OTP as verified in Firestore."""
        try:
            self.db.collection("otp_verifications").document(email.lower().strip()).update({
                "is_verified": True
            })
            return True
        except Exception as e:
            logger.error(f"Error marking OTP as verified: {e}")
            return False

    def delete_otp_record(self, email: str) -> bool:
        """Remove OTP verification from Firestore."""
        try:
            self.db.collection("otp_verifications").document(email.lower().strip()).delete()
            return True
        except Exception as e:
            logger.error(f"Error deleting OTP for {email}: {e}")
            return False

    # -------------------------------------------------------------
    # Document operations
    # -------------------------------------------------------------
    def get_document(self, document_id: str) -> Optional[Dict[str, Any]]:
        """Get document details from PostgreSQL (with Firestore fallback)."""
        conn = self._get_pg_conn()
        if conn:
            try:
                cur = conn.cursor()
                cur.execute("""
                    SELECT id, name, path, type, size_in_mb, status, uploaded_at, 
                           extracted_text, document_type, risk_score, risk_level, summary, analyzed_at, user_id, error_message
                    FROM documents 
                    WHERE id = %s;
                """, (document_id,))
                row = cur.fetchone()
                if row:
                    colnames = [desc[0] for desc in cur.description]
                    doc_dict = dict(zip(colnames, row))
                    for date_field in ["uploaded_at", "analyzed_at"]:
                        if doc_dict.get(date_field) and hasattr(doc_dict[date_field], "isoformat"):
                            doc_dict[date_field] = doc_dict[date_field].isoformat()
                    cur.close()
                    conn.close()
                    return doc_dict
                cur.close()
                conn.close()
            except Exception as pg_err:
                logger.error(f"PostgreSQL error in get_document: {pg_err}")
                if conn:
                    conn.close()
        
        try:
            doc = self.db.collection("documents").document(document_id).get()
            if doc.exists:
                data = doc.to_dict()
                data["id"] = doc.id
                return data
            return None
        except Exception as e:
            logger.error(f"Error getting document {document_id} from Firestore: {e}")
            return None

    def get_user_documents(self, user_id: str) -> List[Dict[str, Any]]:
        """Get all documents belonging to a specific user from PostgreSQL (with Firestore fallback)."""
        conn = self._get_pg_conn()
        if conn:
            try:
                cur = conn.cursor()
                cur.execute("""
                    SELECT id, name, path, type, size_in_mb, status, uploaded_at, 
                           extracted_text, document_type, risk_score, risk_level, summary, analyzed_at, user_id, error_message
                    FROM documents 
                    WHERE user_id = %s
                    ORDER BY uploaded_at DESC;
                """, (user_id,))
                rows = cur.fetchall()
                results = []
                colnames = [desc[0] for desc in cur.description]
                for row in rows:
                    doc_dict = dict(zip(colnames, row))
                    for date_field in ["uploaded_at", "analyzed_at"]:
                        if doc_dict.get(date_field) and hasattr(doc_dict[date_field], "isoformat"):
                            doc_dict[date_field] = doc_dict[date_field].isoformat()
                    results.append(doc_dict)
                cur.close()
                conn.close()
                return results
            except Exception as pg_err:
                logger.error(f"PostgreSQL error in get_user_documents: {pg_err}")
                if conn:
                    conn.close()

        try:
            docs = self.db.collection("documents").where("user_id", "==", user_id).stream()
            results = []
            for doc in docs:
                data = doc.to_dict()
                data["id"] = doc.id
                results.append(data)
            results.sort(key=lambda x: x.get("uploaded_at", ""), reverse=True)
            return results
        except Exception as e:
            logger.error(f"Error getting user documents for {user_id} from Firestore: {e}")
            return []

    def create_document(self, doc_data: Dict[str, Any]) -> bool:
        """Create document metadata record in Firestore."""
        try:
            doc_id = doc_data["id"]
            self.db.collection("documents").document(doc_id).set(doc_data)
            return True
        except Exception as e:
            logger.error(f"Error creating document metadata {doc_data.get('id')}: {e}")
            return False

    def update_document(self, document_id: str, updates: Dict[str, Any]) -> bool:
        """Update document metadata in both Firestore and Supabase PostgreSQL."""
        firestore_success = False
        try:
            self.db.collection("documents").document(document_id).update(updates)
            firestore_success = True
        except Exception as e:
            logger.error(f"Error updating document metadata {document_id} in Firestore: {e}")

        pg_success = False
        conn = self._get_pg_conn()
        if conn:
            try:
                cur = conn.cursor()
                valid_columns = {
                    "name": "%s",
                    "path": "%s",
                    "type": "%s",
                    "size_in_mb": "%s",
                    "status": "%s",
                    "extracted_text": "%s",
                    "document_type": "%s",
                    "risk_score": "%s",
                    "risk_level": "%s",
                    "summary": "%s",
                    "error_message": "%s"
                }
                mapping = {"size_mb": "size_in_mb"}
                set_clauses = []
                values = []
                for k, v in updates.items():
                    col_name = mapping.get(k, k)
                    if col_name in valid_columns:
                        set_clauses.append(f"{col_name} = %s")
                        values.append(v)
                if "analyzed_at" in updates:
                    set_clauses.append("analyzed_at = %s")
                    val = updates["analyzed_at"]
                    if isinstance(val, str):
                        try:
                            if val.endswith("Z"):
                                val = val[:-1] + "+00:00"
                            from datetime import datetime
                            val = datetime.fromisoformat(val)
                        except Exception:
                            val = datetime.now(timezone.utc)
                    values.append(val)
                if set_clauses:
                    values.append(document_id)
                    query = f"UPDATE documents SET {', '.join(set_clauses)} WHERE id = %s"
                    cur.execute(query, tuple(values))
                    conn.commit()
                    pg_success = True
                cur.close()
                conn.close()
            except Exception as pg_err:
                logger.error(f"PostgreSQL error in update_document: {pg_err}")
                if conn:
                    conn.close()

        return firestore_success or pg_success

    def delete_document(self, document_id: str) -> bool:
        """Delete document metadata from Firestore, PostgreSQL, and storage."""
        firestore_success = False
        try:
            doc = self.get_document(document_id)
            if doc:
                storage_path = doc.get("path")
                if storage_path and storage_path.startswith("users/"):
                    try:
                        self.delete_file(storage_path)
                    except Exception as storage_err:
                        logger.warning(f"Failed to delete file from Firebase Storage: {storage_err}")
            self.db.collection("documents").document(document_id).delete()
            firestore_success = True
        except Exception as e:
            logger.error(f"Error deleting document {document_id} from Firestore: {e}")

        pg_success = False
        conn = self._get_pg_conn()
        if conn:
            try:
                cur = conn.cursor()
                cur.execute("DELETE FROM documents WHERE id = %s", (document_id,))
                conn.commit()
                pg_success = True
                cur.close()
                conn.close()
            except Exception as pg_err:
                logger.error(f"PostgreSQL error in delete_document: {pg_err}")
                if conn:
                    conn.close()

        return firestore_success or pg_success

    def get_analysis(self, document_id: str) -> Optional[Dict[str, Any]]:
        """Get document analysis results from PostgreSQL (with Firestore fallback)."""
        conn = self._get_pg_conn()
        if conn:
            try:
                import json
                cur = conn.cursor()
                cur.execute("""
                    SELECT document_id, risk_level, risk_score, summary, ai_confidence, 
                           parties, important_dates, recommendations, raw_analysis_data, created_at
                    FROM analysis 
                    WHERE document_id = %s;
                """, (document_id,))
                row = cur.fetchone()
                if row:
                    colnames = [desc[0] for desc in cur.description]
                    analysis_dict = dict(zip(colnames, row))
                    for json_field in ["parties", "important_dates", "recommendations", "raw_analysis_data"]:
                        val = analysis_dict.get(json_field)
                        if isinstance(val, str):
                            try:
                                analysis_dict[json_field] = json.loads(val)
                            except Exception:
                                pass
                    if analysis_dict.get("created_at") and hasattr(analysis_dict["created_at"], "isoformat"):
                        analysis_dict["created_at"] = analysis_dict["created_at"].isoformat()
                    cur.close()
                    conn.close()
                    return analysis_dict
                cur.close()
                conn.close()
            except Exception as pg_err:
                logger.error(f"PostgreSQL error in get_analysis: {pg_err}")
                if conn:
                    conn.close()

        try:
            doc = self.db.collection("analyses").document(document_id).get()
            if doc.exists:
                return doc.to_dict()
            return None
        except Exception as e:
            logger.error(f"Error getting analysis for {document_id} from Firestore: {e}")
            return None

    def save_analysis(self, document_id: str, analysis_data: Dict[str, Any]) -> bool:
        """Save/Update document analysis results in Firestore."""
        try:
            analysis_data["created_at"] = datetime.now(timezone.utc).isoformat()
            self.db.collection("analyses").document(document_id).set(analysis_data)
            return True
        except Exception as e:
            logger.error(f"Error saving analysis for {document_id}: {e}")
            return False

    def delete_analysis(self, document_id: str) -> bool:
        """Delete analysis document from Firestore."""
        try:
            self.db.collection("analyses").document(document_id).delete()
            return True
        except Exception as e:
            logger.error(f"Error deleting analysis for {document_id}: {e}")
            return False

    def get_clauses(self, document_id: str) -> List[Dict[str, Any]]:
        """Get all clauses extracted for a document from PostgreSQL (with Firestore fallback)."""
        conn = self._get_pg_conn()
        if conn:
            try:
                cur = conn.cursor()
                cur.execute("""
                    SELECT id, document_id, title, content, summary, risk_level, mitigation_advice, created_at
                    FROM clauses 
                    WHERE document_id = %s;
                """, (document_id,))
                rows = cur.fetchall()
                results = []
                colnames = [desc[0] for desc in cur.description]
                for row in rows:
                    clause_dict = dict(zip(colnames, row))
                    if clause_dict.get("created_at") and hasattr(clause_dict["created_at"], "isoformat"):
                        clause_dict["created_at"] = clause_dict["created_at"].isoformat()
                    results.append(clause_dict)
                cur.close()
                conn.close()
                return results
            except Exception as pg_err:
                logger.error(f"PostgreSQL error in get_clauses: {pg_err}")
                if conn:
                    conn.close()

        try:
            clauses_ref = self.db.collection("clauses")
            docs = clauses_ref.where("document_id", "==", document_id).stream()
            results = []
            for doc in docs:
                data = doc.to_dict()
                data["id"] = doc.id
                results.append(data)
            return results
        except Exception as e:
            logger.error(f"Error getting clauses for {document_id} from Firestore: {e}")
            return []

    def save_clause(self, clause_data: Dict[str, Any]) -> bool:
        """Save a single extracted clause to Firestore."""
        try:
            clause_data["created_at"] = datetime.now(timezone.utc).isoformat()
            self.db.collection("clauses").add(clause_data)
            return True
        except Exception as e:
            logger.error(f"Error saving clause: {e}")
            return False

    def delete_document_clauses(self, document_id: str) -> bool:
        """Delete all clauses associated with a document ID."""
        try:
            clauses_ref = self.db.collection("clauses")
            docs = clauses_ref.where("document_id", "==", document_id).stream()
            batch = self.db.batch()
            count = 0
            for doc in docs:
                batch.delete(doc.reference)
                count += 1
            if count > 0:
                batch.commit()
            return True
        except Exception as e:
            logger.error(f"Error deleting clauses for {document_id}: {e}")
            return False

    def get_chat_history(self, document_id: str, user_id: str) -> List[Dict[str, Any]]:
        """Fetch chat history logs for a specific document and user from PostgreSQL (with Firestore fallback)."""
        conn = self._get_pg_conn()
        if conn:
            try:
                cur = conn.cursor()
                cur.execute("""
                    SELECT id, document_id, user_id, query, response, created_at
                    FROM chat_history 
                    WHERE document_id = %s AND user_id = %s
                    ORDER BY created_at ASC;
                """, (document_id, user_id))
                rows = cur.fetchall()
                results = []
                colnames = [desc[0] for desc in cur.description]
                for row in rows:
                    chat_dict = dict(zip(colnames, row))
                    if chat_dict.get("created_at") and hasattr(chat_dict["created_at"], "isoformat"):
                        chat_dict["created_at"] = chat_dict["created_at"].isoformat()
                    results.append(chat_dict)
                cur.close()
                conn.close()
                return results
            except Exception as pg_err:
                logger.error(f"PostgreSQL error in get_chat_history: {pg_err}")
                if conn:
                    conn.close()

        try:
            chats_ref = self.db.collection("chat_history")
            docs = chats_ref.where("document_id", "==", document_id).where("user_id", "==", user_id).stream()
            results = []
            for doc in docs:
                data = doc.to_dict()
                data["id"] = doc.id
                results.append(data)
            results.sort(key=lambda x: x.get("created_at", ""))
            return results
        except Exception as e:
            logger.error(f"Error getting chat history for document {document_id}: {e}")
            return []

    def save_chat_entry(self, chat_data: Dict[str, Any]) -> bool:
        """Save a new chat interaction log to both Firestore and PostgreSQL."""
        firestore_success = False
        try:
            chat_data["created_at"] = datetime.now(timezone.utc).isoformat()
            self.db.collection("chat_history").add(chat_data)
            firestore_success = True
        except Exception as e:
            logger.error(f"Error saving chat entry to Firestore: {e}")

        pg_success = False
        conn = self._get_pg_conn()
        if conn:
            try:
                cur = conn.cursor()
                cur.execute("""
                    INSERT INTO chat_history (document_id, user_id, query, response)
                    VALUES (%s, %s, %s, %s)
                """, (
                    chat_data["document_id"],
                    chat_data["user_id"],
                    chat_data["query"],
                    chat_data["response"]
                ))
                conn.commit()
                pg_success = True
                cur.close()
                conn.close()
            except Exception as pg_err:
                logger.error(f"PostgreSQL error in save_chat_entry: {pg_err}")
                if conn:
                    conn.close()

        return firestore_success or pg_success

    def clear_chat_history(self, document_id: str, user_id: str) -> bool:
        """Clear all chat history for a specific document and user."""
        firestore_success = False
        try:
            chats_ref = self.db.collection("chat_history")
            docs = chats_ref.where("document_id", "==", document_id).where("user_id", "==", user_id).stream()
            batch = self.db.batch()
            count = 0
            for doc in docs:
                batch.delete(doc.reference)
                count += 1
            if count > 0:
                batch.commit()
            firestore_success = True
        except Exception as e:
            logger.error(f"Error clearing chat history from Firestore: {e}")

        pg_success = False
        conn = self._get_pg_conn()
        if conn:
            try:
                cur = conn.cursor()
                cur.execute("DELETE FROM chat_history WHERE document_id = %s AND user_id = %s", (document_id, user_id))
                conn.commit()
                pg_success = True
                cur.close()
                conn.close()
            except Exception as pg_err:
                logger.error(f"PostgreSQL error in clear_chat_history: {pg_err}")
                if conn:
                    conn.close()

        return firestore_success or pg_success

    # -------------------------------------------------------------
    # Translated Summaries caching
    # -------------------------------------------------------------
    def get_translated_summary(self, document_id: str, language: str) -> Optional[Dict[str, Any]]:
        """Get translated summary cached in Firestore."""
        try:
            doc_id = f"{document_id}_{language}"
            doc = self.db.collection("summaries").document(doc_id).get()
            if doc.exists:
                return doc.to_dict()
            return None
        except Exception as e:
            logger.error(f"Error getting translated summary: {e}")
            return None

    def save_translated_summary(self, document_id: str, language: str, summary: str) -> bool:
        """Save translated summary in Firestore."""
        try:
            doc_id = f"{document_id}_{language}"
            data = {
                "document_id": document_id,
                "language": language,
                "summary": summary,
                "created_at": datetime.now(timezone.utc).isoformat()
            }
            self.db.collection("summaries").document(doc_id).set(data)
            return True
        except Exception as e:
            logger.error(f"Error saving translated summary: {e}")
            return False

    # -------------------------------------------------------------
    # Firebase Storage File operations
    # -------------------------------------------------------------
    def upload_file(self, local_path: str, remote_path: str, content_type: str = "application/pdf") -> Optional[str]:
        """Upload local file to Firebase Storage and return public download URL."""
        if not self.bucket:
            logger.warning("Firebase Storage bucket is not initialized. Using local path.")
            return None
        try:
            blob = self.bucket.blob(remote_path)
            blob.upload_from_filename(local_path, content_type=content_type)
            
            # Make public to get public download URL (standard for Firebase apps)
            try:
                blob.make_public()
                return blob.public_url
            except Exception:
                # If make_public is disabled in rules, generate signed URL
                url = blob.generate_signed_url(
                    version="v4",
                    expiration=timedelta(days=365),
                    method="GET"
                )
                return url
        except Exception as e:
            logger.error(f"Failed to upload file to storage: {e}")
            return None

    def upload_file_content(self, content: bytes, remote_path: str, content_type: str = "application/pdf") -> Optional[str]:
        """Upload file content bytes directly to Firebase Storage and return download URL."""
        if not self.bucket:
            return None
        try:
            blob = self.bucket.blob(remote_path)
            blob.upload_from_string(content, content_type=content_type)
            try:
                blob.make_public()
                return blob.public_url
            except Exception:
                url = blob.generate_signed_url(
                    version="v4",
                    expiration=timedelta(days=365),
                    method="GET"
                )
                return url
        except Exception as e:
            logger.error(f"Failed to upload raw bytes to storage: {e}")
            return None

    def download_file_to_local(self, remote_path: str, local_path: str) -> bool:
        """Download file from Firebase Storage to local filesystem."""
        if not self.bucket:
            return False
        try:
            blob = self.bucket.blob(remote_path)
            blob.download_to_filename(local_path)
            return True
        except Exception as e:
            logger.error(f"Failed to download file from storage: {e}")
            return False

    def delete_file(self, remote_path: str) -> bool:
        """Delete file from Firebase Storage."""
        if not self.bucket:
            return False
        try:
            blob = self.bucket.blob(remote_path)
            if blob.exists():
                blob.delete()
                return True
            return False
        except Exception as e:
            logger.error(f"Failed to delete file {remote_path} from storage: {e}")
            return False

    def get_user_stats(self, user_id: str) -> dict:
        """Get user statistics: documents analyzed, high risk count, ai chat count."""
        conn = self._get_pg_conn()
        stats = {"documents_analyzed": 0, "high_risk_count": 0, "ai_chat_count": 0}
        if conn:
            try:
                cur = conn.cursor()
                cur.execute("SELECT COUNT(*) FROM documents WHERE user_id = %s", (user_id,))
                stats["documents_analyzed"] = cur.fetchone()[0]
                cur.execute("SELECT COUNT(*) FROM documents WHERE user_id = %s AND risk_level = 'High'", (user_id,))
                stats["high_risk_count"] = cur.fetchone()[0]
                cur.execute("SELECT COUNT(*) FROM chat_history WHERE user_id = %s", (user_id,))
                stats["ai_chat_count"] = cur.fetchone()[0]
                cur.close()
                conn.close()
                return stats
            except Exception as pg_err:
                logger.error(f"PostgreSQL error in get_user_stats: {pg_err}")
                if conn:
                    conn.close()
        try:
            docs_ref = self.db.collection("documents").where("user_id", "==", user_id).get()
            stats["documents_analyzed"] = len(docs_ref)
            stats["high_risk_count"] = sum(1 for d in docs_ref if d.to_dict().get("risk_level") == "High")
            chats_ref = self.db.collection("chat_history").where("user_id", "==", user_id).get()
            stats["ai_chat_count"] = len(chats_ref)
        except Exception as e:
            logger.error(f"Error getting user stats from Firestore: {e}")
        return stats


# Singleton instance
firebase_service = FirebaseService()
