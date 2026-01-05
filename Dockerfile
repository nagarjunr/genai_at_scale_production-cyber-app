# Build frontend
FROM node:20-alpine AS frontend-build

# Proxy support for corporate networks
ARG http_proxy
ARG https_proxy
ARG HTTP_PROXY
ARG HTTPS_PROXY
ENV http_proxy=${http_proxy} \
    https_proxy=${https_proxy} \
    HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY}

WORKDIR /app
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ .
RUN npm run build

# Production image
FROM python:3.12-slim

# Proxy support for corporate networks
ARG http_proxy
ARG https_proxy
ARG HTTP_PROXY
ARG HTTPS_PROXY
ENV http_proxy=${http_proxy} \
    https_proxy=${https_proxy} \
    HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY}

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install uv for Python package management
RUN pip install uv

# Install certifi first
RUN pip install certifi

RUN pip install semgrep

# # Install semgrep CLI with custom certificates from certifi
# RUN CACERT_PATH=$(python -c "import certifi; print(certifi.where())") && \
#     export SSL_CERT_FILE="${CACERT_PATH}" && \
#     export REQUESTS_CA_BUNDLE="${CACERT_PATH}" && \
#     pip install --no-cache-dir semgrep

# Copy Python dependencies and install
COPY backend/pyproject.toml backend/uv.lock* ./
RUN uv sync --frozen

# Copy backend source
COPY backend/ ./

# Copy Next.js static export (from 'out' directory)
COPY --from=frontend-build /app/out ./static

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Expose port for Cloud Run / Azure Container Instances
EXPOSE 8000

# Start the FastAPI server
CMD ["uv", "run", "uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]