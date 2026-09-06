# Production Dockerfile for ParkFlow On-Premises Deployment
FROM python:3.11-slim

# Labels for on-prem compliance & asset tracking
LABEL maintainer="ParkFlow Ops <ops@parkflow.local>"
LABEL version="1.0.0"
LABEL description="ParkFlow On-Premises Smart Parking Management System"

# Prevent python from writing pyc files to disc and buffering stdout/stderr
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PARKFLOW_DB_PATH=/app/data/parking.db

WORKDIR /app

# Install security updates and curl for container healthcheck
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY . .

# Create non-root user and persistent data directory
RUN useradd -m -u 1000 appuser && \
    mkdir -p /app/data && \
    chown -R appuser:appuser /app

USER appuser

# Health check to monitor Streamlit's internal healthz endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8501/_stcore/health || exit 1

EXPOSE 8501

CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0", "--browser.serverAddress=0.0.0.0", "--server.headless=true"]