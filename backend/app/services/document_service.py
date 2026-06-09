"""
Document Processing Service for LexGuard AI
Handles text extraction from PDF, DOCX, TXT, and images.
"""
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


def extract_text_from_pdf(file_path: str) -> str:
    """Extract text from PDF files using pdfplumber."""
    try:
        # pyrefly: ignore [missing-import]
        import pdfplumber
        text = ""
        with pdfplumber.open(file_path) as pdf:
            for page in pdf.pages:
                page_text = page.extract_text()
                if page_text:
                    text += page_text + "\n\n"
        
        # If no text extracted (scanned PDF), try OCR
        if not text.strip():
            text = extract_text_from_image(file_path)
        
        return text.strip()
    except Exception as e:
        print(f"PDF extraction error: {e}")
        traceback.print_exc()
        # Fallback to PyPDF2
        try:
            # pyrefly: ignore [missing-import]
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
            return ""


def extract_text_from_docx(file_path: str) -> str:
    """Extract text from DOCX files."""
    try:
        # pyrefly: ignore [missing-import]
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
        
        return text.strip()
    except Exception as e:
        print(f"DOCX extraction error: {e}")
        traceback.print_exc()
        return ""


def extract_text_from_txt(file_path: str) -> str:
    """Extract text from plain text files."""
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            return f.read().strip()
    except Exception as e:
        print(f"TXT extraction error: {e}")
        return ""


def extract_text_from_image(file_path: str) -> str:
    """Extract text from images using OCR (EasyOCR or pytesseract)."""
    text = ""
    
    # Try EasyOCR first
    try:
        # pyrefly: ignore [missing-import]
        import easyocr
        reader = easyocr.Reader(['en'], gpu=False)
        results = reader.readtext(file_path, detail=0)
        text = "\n".join(results)
        if text.strip():
            return text.strip()
    except ImportError:
        pass
    except Exception as e:
        print(f"EasyOCR failed: {e}")
    
    # Fallback to pytesseract
    try:
        from app.core.config import settings
        # pyrefly: ignore [missing-import]
        import pytesseract
        # pyrefly: ignore [missing-import]
        from PIL import Image
        
        # Set tesseract path if it exists
        if os.path.exists(settings.TESSERACT_CMD):
            pytesseract.pytesseract.tesseract_cmd = settings.TESSERACT_CMD
            
        img = Image.open(file_path)
        text = pytesseract.image_to_string(img)
        return text.strip()
    except ImportError:
        print("Neither EasyOCR nor pytesseract is installed. OCR unavailable.")
    except Exception as e:
        print(f"Pytesseract failed: {e}")
    
    return text


def extract_text(file_path: str, file_type: str) -> str:
    """Main dispatcher — extract text based on file type."""
    file_type = file_type.lower()
    
    if file_type in ['pdf', 'application/pdf']:
        return extract_text_from_pdf(file_path)
    elif file_type in ['docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']:
        return extract_text_from_docx(file_path)
    elif file_type in ['txt', 'text/plain']:
        return extract_text_from_txt(file_path)
    elif file_type in ['jpg', 'jpeg', 'png', 'image/jpeg', 'image/png', 'image/jpg']:
        return extract_text_from_image(file_path)
    else:
        raise ValueError(f"Unsupported file type: {file_type}")


def get_file_extension(filename: str) -> str:
    """Get clean file extension from filename."""
    _, ext = os.path.splitext(filename)
    return ext.lstrip('.').lower()


SUPPORTED_EXTENSIONS = {'pdf', 'docx', 'txt', 'jpg', 'jpeg', 'png'}
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
    Optimized: Queries local PostgreSQL database first, falls back to Supabase Storage only if needed.
    """
    try:
        from app.services.firebase_service import firebase_service
        conn = firebase_service._get_pg_conn()
        if conn:
            try:
                cur = conn.cursor()
                cur.execute("SELECT SUM(size_in_mb) FROM documents WHERE user_id = %s", (user_id,))
                result = cur.fetchone()
                cur.close()
                conn.close()
                if result and result[0] is not None:
                    return float(result[0])
            except Exception as e:
                print(f"PostgreSQL storage query failed, trying fallback: {e}")
                if conn:
                    conn.close()
        
        # Fallback to direct Supabase Storage API if DB connection fails
        print(f"Running fallback storage usage lookup for user {user_id} via Supabase Storage...")
        supabase = get_supabase()
        files = supabase.storage.from_("legal-documents").list(f"users/{user_id}/documents")
        total_size_bytes = sum(f.get('metadata', {}).get('size', 0) for f in files if f.get('metadata')) if files else 0
        return total_size_bytes / (1024 * 1024)
    except Exception as e:
        print(f"Failed to fetch storage usage for user {user_id}: {e}")
        return 0.0

