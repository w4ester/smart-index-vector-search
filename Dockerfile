FROM python:3.9-slim

WORKDIR /app

COPY backend/requirements.txt .
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        tesseract-ocr \
        libtesseract-dev \
        poppler-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN mkdir -p /app/chroma_db && chmod 777 /app/chroma_db

CMD ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000"]