FROM python:3.11

WORKDIR /app

ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
COPY pyproject.toml .
COPY src/ src/
COPY scripts/ scripts/
COPY .env .

RUN pip install -r requirements.txt
RUN pip install --no-cache-dir . \
    uvicorn[standard] \
    uvloop \
    httptools

RUN useradd -m -u 1000 appuser
USER appuser

EXPOSE 8000

CMD ["python3","src/main.py"] 