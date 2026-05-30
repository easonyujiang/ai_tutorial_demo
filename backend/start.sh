#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
export PYTHONDONTWRITEBYTECODE=1
source venv/bin/activate
exec python -m uvicorn main:app --host 0.0.0.0 --port 8000 --log-level info
