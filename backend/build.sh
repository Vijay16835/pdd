#!/usr/bin/env bash
# Render build script — installs system dependencies before pip install.
# Render's free-tier uses Ubuntu (Debian-based), so apt-get is available.
# IMPORTANT: In Render dashboard, set Build Command to: ./build.sh
set -e

echo "=== [build.sh] START — $(date) ==="
echo "=== [build.sh] Installing system dependencies ==="
apt-get update -qq
apt-get install -y --no-install-recommends tesseract-ocr tesseract-ocr-eng libgl1

echo "=== [build.sh] Verifying tesseract installation ==="
which tesseract && echo "[OK] which tesseract: $(which tesseract)" || echo "[FAIL] tesseract not found in PATH"
tesseract --version && echo "[OK] tesseract --version succeeded" || echo "[FAIL] tesseract --version failed"
echo "[INFO] TESSERACT_CMD will be: /usr/bin/tesseract"
ls -la /usr/bin/tesseract 2>/dev/null && echo "[OK] /usr/bin/tesseract exists" || echo "[FAIL] /usr/bin/tesseract not found"

echo "=== [build.sh] Installing Python dependencies ==="
pip install --upgrade pip
pip install -r requirements.txt

echo "=== [build.sh] Build complete — $(date) ==="
