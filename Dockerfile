# Stage 1: Builder
FROM ghcr.io/astral-sh/uv:python3.14-trixie-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    libc6-dev \
    libffi-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy custom CA certificate if it exists
COPY cacerts.pem cacerts.pem

# Update certificate store with our custom certificate
RUN if [ -f cacerts.pem ]; then \
    mkdir -p /usr/local/share/ca-certificates && \
    cp cacerts.pem /usr/local/share/ca-certificates/cacerts.crt && \
    update-ca-certificates; \
fi

# Set the working directory in the builder stage
WORKDIR /app

# Copy dependency files
COPY pyproject.toml ./

# Create virtual environment
RUN uv venv

# Install dependencies using uv
RUN uv sync --native-tls

# Stage 2: Runner
# Use a minimal Python image for the final runtime
FROM python:3.14-slim AS runner

# Install standard ca-certificates
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy custom CA certificate if it exists
COPY cacerts.pem cacerts.pem

# Update certificate store with our custom certificate
RUN if [ -f cacerts.pem ]; then \
    mkdir -p /usr/local/share/ca-certificates && \
    cp cacerts.pem /usr/local/share/ca-certificates/cacerts.crt && \
    update-ca-certificates; \
fi

# Set standard environment variables for Python
ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

# Set environment variables for Python to use the virtual environment
ENV PATH="/app/.venv/bin:$PATH"

# Copy only the installed dependencies from the builder stage
COPY --from=builder /app/.venv /app/.venv

# Copy the application code
COPY agent.py ./

# Expose the port the FastAPI app will run on
EXPOSE 8080

# Command to run the FastAPI application using uvicorn
CMD ["uvicorn", "agent:app", "--host", "0.0.0.0", "--port", "8080"]
