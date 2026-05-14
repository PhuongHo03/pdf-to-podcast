FROM python:3.11-slim

USER root
ARG DEBIAN_FRONTEND=noninteractive

RUN set -x \
    && apt-get update \
    && apt-get -y install wget curl man git less openssl libssl-dev unzip unar build-essential aria2 tmux vim \
    && apt-get install -y openssh-server sox libsox-fmt-all libsox-fmt-mp3 libsndfile1-dev ffmpeg \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean


WORKDIR /workspace

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
            fastapi uvicorn edge-tts elevenlabs pydantic redis httpx \
            opentelemetry-api \
            opentelemetry-sdk \
            opentelemetry-instrumentation-fastapi \
            opentelemetry-instrumentation-requests \
            opentelemetry-instrumentation-redis \
            opentelemetry-exporter-otlp-proto-grpc \
            opentelemetry-instrumentation-httpx \
            opentelemetry-instrumentation-urllib3 \
            ujson

# Copy shared package first
COPY shared /shared
RUN set -eux; \
    for attempt in 1 2 3; do \
        python -m pip install --no-cache-dir --retries 10 --timeout 60 /shared && break; \
        status="$?"; \
        if [ "$attempt" = "3" ]; then exit "$status"; fi; \
        sleep "$((attempt * 10))"; \
    done

# Copy service files
COPY services/TTSService/main.py ./

EXPOSE 8889

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8889"]
