FROM python:3.9-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Create config directory
RUN mkdir -p /app/config

# Install Python dependencies
RUN set -eux; \
    pip_retry() { \
        for attempt in 1 2 3; do \
            python -m pip install --no-cache-dir --retries 10 --timeout 60 "$@" && return 0; \
            status="$?"; \
            if [ "$attempt" = "3" ]; then return "$status"; fi; \
            sleep "$((attempt * 10))"; \
        done; \
    }; \
    pip_retry --upgrade pip setuptools wheel; \
    pip_retry \
            fastapi uvicorn pydantic python-dotenv jinja2 redis minio opentelemetry-api \
            opentelemetry-sdk \
            opentelemetry-instrumentation-fastapi \
            opentelemetry-instrumentation-requests \
            opentelemetry-instrumentation-redis \
            opentelemetry-exporter-otlp-proto-grpc \
            opentelemetry-instrumentation-httpx \
            opentelemetry-instrumentation-urllib3 \
            ujson

WORKDIR /app

COPY shared /shared
RUN set -eux; \
    for attempt in 1 2 3; do \
        python -m pip install --no-cache-dir --retries 10 --timeout 60 /shared && break; \
        status="$?"; \
        if [ "$attempt" = "3" ]; then exit "$status"; fi; \
        sleep "$((attempt * 10))"; \
    done

# Copy service files
COPY services/AgentService/main.py ./
COPY services/AgentService/podcast_prompts.py ./
COPY services/AgentService/monologue_prompts.py ./
COPY services/AgentService/podcast_flow.py ./
COPY services/AgentService/monologue_flow.py ./

EXPOSE 8964

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8964"]
