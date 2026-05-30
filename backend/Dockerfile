FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py config.py ./
COPY models/ ./models/
COPY routers/ ./routers/
COPY services/ ./services/
COPY infrastructure/ ./infrastructure/

RUN mkdir -p /tmp/tutorial_downloads /tmp/tutorial_compress

ENV PYTHONUNBUFFERED=1
ENV OCR_ENGINE=easyocr
ENV OCR_LANG=ch_sim

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD python -c "from urllib.request import urlopen; urlopen('http://localhost:8000/')" || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
