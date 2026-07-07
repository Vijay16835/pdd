import os
import traceback
from typing import Optional

# ---------------------------------------------------------------------------
# Supabase singleton — created once at module load, reused on every request.
# ---------------------------------------------------------------------------
_supabase_client = None

def get_supabase():
    """Return the shared Supabase client, initialising it on first call."""
    global _supabase_client
    if _supabase_client is None:
        from supabase import create_client
        from app.core.config import settings
        _supabase_client = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)
    return _supabase_client


class TextExtractionError(Exception):
    """Custom exception raised when text extraction fails."""
    pass


def extract_text_from_pdf(file_path: str) -> str:
    """Extract text from PDF files using pdfplumber."""
    try:
        import pdfplumber
        text = ""
        with pdfplumber.open(file_path) as pdf:
            for page in pdf.pages:
                page_text = page.extract_text()
                if page_text:
                    text += page_text + "\n\n"
        return text.strip()
    except Exception as e:
        print(f"PDF extraction error: {e}")
        # Fallback to PyPDF2
        try:
            import PyPDF2
            text = ""
            with open(file_path, 'rb') as f:
                reader = PyPDF2.PdfReader(f)
                for page in reader.pages:
                    page_text = page.extract_text()
                    if page_text:
                        text += page_text + "\n\n"
            return text.strip()
        except Exception as e2:
            print(f"PyPDF2 fallback failed: {e2}")
            raise TextExtractionError("PDF text extraction failed") from e2


def extract_text_from_doc(file_path: str) -> str:
    """Extract text from legacy DOC files using legacy-doc."""
    try:
        from legacy_doc import extract_text as legacy_extract
        with open(file_path, "rb") as f:
            result = legacy_extract(f.read())
            if hasattr(result, 'text'):
                text = result.text
            else:
                text = str(result)
        if not text.strip():
            raise TextExtractionError("Unable to extract readable text from document.")
        return text.strip()
    except TextExtractionError:
        raise
    except Exception as e:
        print(f"DOC extraction error: {e}")
        traceback.print_exc()
        raise TextExtractionError("Unsupported file structure") from e


def extract_text_from_docx(file_path: str) -> str:
    """Extract text from DOCX files."""
    try:
        import docx
        doc = docx.Document(file_path)
        text = ""
        for paragraph in doc.paragraphs:
            if paragraph.text.strip():
                text += paragraph.text + "\n"
        
        # Also extract from tables
        for table in doc.tables:
            for row in table.rows:
                row_text = " | ".join(cell.text.strip() for cell in row.cells if cell.text.strip())
                if row_text:
                    text += row_text + "\n"
        
        if not text.strip():
            raise TextExtractionError("Unable to extract readable text from document.")
            
        return text.strip()
    except TextExtractionError:
        raise
    except Exception as e:
        print(f"DOCX extraction error: {e}")
        traceback.print_exc()
        raise TextExtractionError("Unsupported file structure") from e


def extract_text_from_txt(file_path: str) -> str:
    """Extract text from plain text files."""
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            text = f.read().strip()
        if not text:
            raise TextExtractionError("Unable to extract readable text from document.")
        return text
    except TextExtractionError:
        raise
    except Exception as e:
        print(f"TXT extraction error: {e}")
        raise TextExtractionError("Unsupported file structure") from e


# ---------------------------------------------------------------------------
# Tesseract Diagnostic — called once at module import and on each OCR attempt
# ---------------------------------------------------------------------------
def _log_tesseract_diagnostics() -> str:
    """
    Run diagnostic checks for Tesseract availability and log results.
    Returns the resolved tesseract binary path (or empty string on failure).
    """
    import shutil
    import subprocess
    from app.core.config import settings

    print("[TESS-DIAG] === Tesseract Diagnostic ===")

    # 1. Check configured path
    configured_path = settings.TESSERACT_CMD
    exists = os.path.exists(configured_path)
    print(f"[TESS-DIAG] settings.TESSERACT_CMD = {configured_path!r}")
    print(f"[TESS-DIAG] os.path.exists(configured_path) = {exists}")

    # 2. which tesseract
    which_path = shutil.which("tesseract")
    print(f"[TESS-DIAG] shutil.which('tesseract') = {which_path!r}")

    # 3. tesseract --version
    resolved_path = configured_path if exists else (which_path or "tesseract")
    try:
        result = subprocess.run(
            [resolved_path, "--version"],
            capture_output=True, text=True, timeout=10
        )
        version_out = (result.stdout or "").strip() or (result.stderr or "").strip()
        print(f"[TESS-DIAG] tesseract --version output: {version_out[:200]}")
        print(f"[TESS-DIAG] return code: {result.returncode}")
    except FileNotFoundError:
        print(f"[TESS-DIAG] ERROR: tesseract binary not found at {resolved_path!r}")
        resolved_path = ""
    except Exception as diag_err:
        print(f"[TESS-DIAG] ERROR running tesseract --version: {diag_err}")
        resolved_path = ""

    print("[TESS-DIAG] === End Diagnostic ===")
    return resolved_path


def preprocess_image_pillow(file_path: str):
    """
    Preprocess the image using Pillow only (no OpenCV dependency).
    Steps:
      1. Open with Pillow — handles EXIF orientation automatically.
      2. Convert to RGB (removes alpha, handles palette modes).
      3. Convert to grayscale (L mode) for better OCR accuracy.
    Returns a PIL Image object ready for pytesseract.
    """
    from PIL import Image, ImageOps, ImageFilter

    with Image.open(file_path) as pil_img:
        # Fix EXIF orientation
        pil_img = ImageOps.exif_transpose(pil_img)
        # Convert to RGB first (handles RGBA, P/palette, etc.)
        pil_img = pil_img.convert("RGB")
        # Convert to grayscale for OCR
        gray = pil_img.convert("L")
        # Mild sharpening to improve character definition
        sharpened = gray.filter(ImageFilter.SHARPEN)
        # Return a copy so the context manager doesn't close it prematurely
        return sharpened.copy()


def extract_text_from_image(file_path: str) -> str:
    """
    Extract text from images using Pillow + pytesseract.
    
    Diagnostic flow:
      1. Log tesseract binary availability (path, which, --version).
      2. Preprocess image with Pillow (EXIF correction, grayscale).
      3. Run pytesseract.image_to_string().
      4. Log extracted text length.
      5. If length == 0 → raise TextExtractionError (do NOT proceed to Groq).
    """
    print("[IMAGE] Image received")
    print("[OCR] OCR started — engine: pytesseract (Pillow preprocessing)")

    # --- Step 1: Tesseract diagnostics ---
    resolved_tess_path = _log_tesseract_diagnostics()

    # --- Step 2: Configure pytesseract binary path ---
    import pytesseract
    from app.core.config import settings

    if resolved_tess_path and os.path.exists(resolved_tess_path):
        pytesseract.pytesseract.tesseract_cmd = resolved_tess_path
        print(f"[OCR] pytesseract.tesseract_cmd set to: {resolved_tess_path!r}")
    else:
        # Let pytesseract use its own default discovery
        print("[OCR] WARNING: tesseract_cmd not explicitly set — relying on system PATH")

    # --- Step 3: Preprocess image ---
    try:
        pil_img = preprocess_image_pillow(file_path)
        print(f"[OCR] Image preprocessed: size={pil_img.size}, mode={pil_img.mode}")
    except Exception as pre_err:
        print(f"[OCR] Pillow preprocessing failed: {pre_err}. Using raw image.")
        from PIL import Image
        try:
            pil_img = Image.open(file_path).convert("L")
        except Exception as raw_err:
            raise TextExtractionError(f"Cannot open image file: {raw_err}") from raw_err

    # --- Step 4: Run OCR ---
    try:
        extracted_text = pytesseract.image_to_string(pil_img)
        print(f"[OCR] pytesseract.image_to_string() returned {len(extracted_text)} chars")
    except pytesseract.TesseractNotFoundError as tnf:
        print(f"[OCR] CRITICAL: TesseractNotFoundError — {tnf}")
        print("[OCR] tesseract-ocr binary is NOT installed or not on PATH.")
        print("[OCR] Ensure build.sh runs: apt-get install -y tesseract-ocr tesseract-ocr-eng")
        raise TextExtractionError("Tesseract OCR engine not found on server.") from tnf
    except Exception as ocr_err:
        print(f"[OCR] pytesseract.image_to_string() raised: {ocr_err}")
        raise TextExtractionError(f"OCR extraction failed: {ocr_err}") from ocr_err

    # --- Step 5: Validate extracted text ---
    stripped_text = extracted_text.strip()
    print(f"[OCR] Extracted text length (stripped): {len(stripped_text)}")

    if len(stripped_text) == 0:
        print("[OCR] STOP: extracted_text length is 0. OCR produced no output.")
        print("[OCR] Possible causes: blank/low-quality image, wrong language pack, Tesseract config.")
        print("[OCR] NOT proceeding to Groq AI — fixing OCR is required first.")
        raise TextExtractionError(
            "No readable text found in image. OCR returned empty output."
        )

    print("[OCR] OCR completed successfully.")
    print(f"[OCR] First 200 chars of extracted text: {stripped_text[:200]!r}")
    return stripped_text


def ocr_pdf(file_path: str) -> str:
    """Perform OCR on a PDF by rendering pages as images and running OCR on them."""
    import pypdfium2 as pdfium
    import tempfile
    
    print("[OCR] OCR started")
    text = ""
    pdf = None
    try:
        pdf = pdfium.PdfDocument(file_path)
        for i in range(len(pdf)):
            page = pdf.get_page(i)
            pil_image = page.render(scale=2).to_pil()
            
            # Save page image to temporary file
            with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
                temp_img_path = tmp.name
            try:
                pil_image.save(temp_img_path)
                page_text = extract_text_from_image(temp_img_path)
                if page_text:
                    text += page_text + "\n\n"
            finally:
                if os.path.exists(temp_img_path):
                    os.remove(temp_img_path)
    except Exception as e:
        print(f"ocr_pdf failed: {e}")
        raise TextExtractionError("OCR extraction failed") from e
    finally:
        if pdf:
            pdf.close()
            
    print("[OCR] OCR completed")
    if not text.strip():
        raise TextExtractionError("OCR extraction failed")
    return text.strip()


def extract_text(file_path: str, file_type: str) -> str:
    """Main dispatcher — extract text based on file type."""
    file_type = file_type.lower()
    print("[EXTRACT] Starting extraction")
    
    text = ""
    try:
        if file_type in ['pdf', 'application/pdf']:
            text = extract_text_from_pdf(file_path)
        elif file_type in ['doc', 'docx', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']:
            if file_type in ['doc', 'application/msword'] or file_path.endswith('.doc'):
                text = extract_text_from_doc(file_path)
            else:
                text = extract_text_from_docx(file_path)
        elif file_type in ['txt', 'text/plain']:
            text = extract_text_from_txt(file_path)
        elif file_type in ['jpg', 'jpeg', 'png', 'image/jpeg', 'image/png', 'image/jpg']:
            text = extract_text_from_image(file_path)
        else:
            raise TextExtractionError("Unsupported file structure")
    except TextExtractionError:
        raise
    except Exception as e:
        print(f"Extraction failed: {e}")
        traceback.print_exc()
        if file_type in ['pdf', 'application/pdf']:
            raise TextExtractionError("PDF text extraction failed") from e
        elif file_type in ['doc', 'docx', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']:
            raise TextExtractionError("Unsupported file structure") from e
        elif file_type in ['jpg', 'jpeg', 'png', 'image/jpeg', 'image/png', 'image/jpg']:
            raise TextExtractionError("OCR extraction failed") from e
        else:
            raise TextExtractionError("Unsupported file structure") from e

    # OCR Fallback if text is empty
    if not text.strip():
        print("[EXTRACT] Extracted text empty. Starting OCR fallback.")
        if file_type in ['pdf', 'application/pdf']:
            try:
                text = ocr_pdf(file_path)
            except Exception as ocr_err:
                raise TextExtractionError("OCR extraction failed") from ocr_err
        elif file_type in ['jpg', 'jpeg', 'png', 'image/jpeg', 'image/png', 'image/jpg']:
            try:
                text = extract_text_from_image(file_path)
            except Exception as ocr_err:
                raise TextExtractionError("OCR extraction failed") from ocr_err
        else:
            raise TextExtractionError("Unable to extract readable text from document.")
            
    if not text.strip():
        if file_type in ['pdf', 'application/pdf'] or file_type in ['jpg', 'jpeg', 'png', 'image/jpeg', 'image/png', 'image/jpg']:
            raise TextExtractionError("OCR extraction failed")
        else:
            raise TextExtractionError("Unable to extract readable text from document.")
            
    print(f"[EXTRACT] Text length: {len(text)}")
    return text.strip()


def get_file_extension(filename: str) -> str:
    """Get clean file extension from filename."""
    _, ext = os.path.splitext(filename)
    return ext.lstrip('.').lower()


SUPPORTED_EXTENSIONS = {'pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png'}
MAX_FILE_SIZE_MB = 20

def validate_file(filename: str, file_size: int) -> tuple:
    """Validate file type and size. Returns (is_valid, error_message)."""
    ext = get_file_extension(filename)
    if ext not in SUPPORTED_EXTENSIONS:
        return False, f"Unsupported file type: .{ext}. Supported: {', '.join(SUPPORTED_EXTENSIONS)}"
    
    size_mb = file_size / (1024 * 1024)
    if size_mb > MAX_FILE_SIZE_MB:
        return False, f"File too large: {size_mb:.1f}MB. Maximum: {MAX_FILE_SIZE_MB}MB"
    
    return True, ""


def get_user_storage_usage_mb(user_id: str) -> float:
    """Calculate the total storage used by a user in MB.
    Includes:
    - Uploaded files (from PostgreSQL/Firestore, checking local disk or Supabase Storage size)
    - Generated reports (from local disk reports directory matching user's document IDs)
    """
    total_size_bytes = 0
    doc_ids_and_sizes = {}  # doc_id -> size_in_bytes

    # 1. Fetch documents from PostgreSQL
    try:
        from app.services.firebase_service import firebase_service
        conn = firebase_service._get_pg_conn()
        if conn:
            try:
                cur = conn.cursor()
                cur.execute("SELECT id, size_in_mb FROM documents WHERE user_id = %s", (user_id,))
                rows = cur.fetchall()
                for row in rows:
                    doc_id = row[0]
                    size_mb = row[1] or 0.0
                    doc_ids_and_sizes[doc_id] = int(size_mb * 1024 * 1024)
                cur.close()
                conn.close()
            except Exception as e:
                print(f"Error querying PostgreSQL documents: {e}")
                if conn:
                    conn.close()
    except Exception as e:
        print(f"PostgreSQL connection error: {e}")

    # 2. Fetch documents from Firestore
    try:
        from app.services.firebase_service import firebase_service
        if firebase_service.db:
            docs = firebase_service.db.collection("documents").where("user_id", "==", user_id).stream()
            for doc in docs:
                doc_id = doc.id
                data = doc.to_dict()
                size_mb = data.get("size_in_mb", 0.0) or 0.0
                if doc_id not in doc_ids_and_sizes:
                    doc_ids_and_sizes[doc_id] = int(size_mb * 1024 * 1024)
    except Exception as e:
        print(f"Error querying Firestore documents: {e}")

    # 3. Fetch documents from Supabase Storage
    try:
        supabase = get_supabase()
        files = supabase.storage.from_("legal-documents").list(f"users/{user_id}/documents")
        if files:
            for f in files:
                name = f.get("name")
                if name:
                    doc_id, ext = os.path.splitext(name)
                    metadata = f.get('metadata')
                    if metadata:
                        size_bytes = metadata.get('size', 0)
                        doc_ids_and_sizes[doc_id] = size_bytes
    except Exception as e:
        print(f"Error listing Supabase Storage files: {e}")

    # 4. Check actual file sizes on local disk
    from app.core.config import settings
    upload_dir = settings.UPLOAD_DIR
    local_doc_sizes = {}
    if os.path.exists(upload_dir):
        try:
            for filename in os.listdir(upload_dir):
                filepath = os.path.join(upload_dir, filename)
                if os.path.isfile(filepath):
                    doc_id, ext = os.path.splitext(filename)
                    if doc_id in doc_ids_and_sizes:
                        local_doc_sizes[doc_id] = os.path.getsize(filepath)
        except Exception as e:
            print(f"Error scanning local upload directory: {e}")

    # For each found document ID, use local size if it exists, else the db/remote size
    for doc_id, remote_size in doc_ids_and_sizes.items():
        if doc_id in local_doc_sizes:
            total_size_bytes += local_doc_sizes[doc_id]
        else:
            total_size_bytes += remote_size

    # 5. Check generated reports
    # Reports are under settings.UPLOAD_DIR/reports/LexGuard_Analysis_{doc_id}.{ext}
    reports_dir = os.path.join(upload_dir, "reports")
    if os.path.exists(reports_dir):
        try:
            for filename in os.listdir(reports_dir):
                filepath = os.path.join(reports_dir, filename)
                if os.path.isfile(filepath):
                    # Check if this report belongs to any of the user's document IDs
                    for doc_id in doc_ids_and_sizes.keys():
                        if f"LexGuard_Analysis_{doc_id}" in filename:
                            total_size_bytes += os.path.getsize(filepath)
                            break
        except Exception as e:
            print(f"Error scanning local reports directory: {e}")

    total_size_mb = total_size_bytes / (1024 * 1024)
    return round(total_size_mb, 2)
