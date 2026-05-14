FROM python:3.11-slim

WORKDIR /app

# Install only the necessary Python packages
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
            fastapi \
            uvicorn \
            python-multipart \
            httpx \
            redis \
            asyncio \
            requests \
            opentelemetry-api \
            opentelemetry-sdk \
            opentelemetry-instrumentation-fastapi \
            opentelemetry-instrumentation-requests \
            opentelemetry-instrumentation-redis \
            opentelemetry-exporter-otlp-proto-grpc \
            opentelemetry-instrumentation-httpx \
            opentelemetry-instrumentation-urllib3 \
            ujson \
            pypdf

# Copy shared package
COPY shared /shared
RUN set -eux; \
    for attempt in 1 2 3; do \
        python -m pip install --no-cache-dir --retries 10 --timeout 60 /shared && break; \
        status="$?"; \
        if [ "$attempt" = "3" ]; then exit "$status"; fi; \
        sleep "$((attempt * 10))"; \
    done

# Copy the service code
COPY services/PDFService/main.py ./

EXPOSE 8003

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8003"]
