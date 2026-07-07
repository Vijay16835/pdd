#!/usr/bin/env bash
# Render build script — installs system dependencies before pip install.
# Render's free-tier uses Ubuntu (Debian-based), so apt-get is available.
set -e

echo "=== [build.sh] Installing system dependencies ==="
apt-get update -qq
apt-get install -y --no-install-recommends tesseract-ocr tesseract-ocr-eng libgl1

echo "=== [build.sh] Tesseract version ==="
tesseract --version

echo "=== [build.sh] Installing Python dependencies ==="
pip install --upgrade pip
pip install -r requirements.txt

echo "=== [build.sh] Build complete ==="
