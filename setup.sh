#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

AUTO_PORTS_FILE="${PROJECT_ROOT}/.auto-ports.env"
AUTO_COMPOSE_OVERRIDE="${PROJECT_ROOT}/.auto-ports.compose.yaml"
FRONTEND_LOG="${PROJECT_ROOT}/frontend/output.log"
FRONTEND_PID_FILE="${PROJECT_ROOT}/frontend/.frontend.pid"
DEPS_HASH_FILE="${PROJECT_ROOT}/.deps.hash"

ensure_env_file() {
    if [ ! -f "${PROJECT_ROOT}/.env" ]; then
        if [ ! -f "${PROJECT_ROOT}/.env.example" ]; then
            echo "Error: .env is missing and .env.example was not found."
            exit 1
        fi
        cp "${PROJECT_ROOT}/.env.example" "${PROJECT_ROOT}/.env"
        echo "Created .env from .env.example. Replace placeholder API keys for full podcast generation."
    fi
}

usage() {
        cat <<'EOF'
Usage:
    bash setup.sh --up     Start/restart whole system (venv + deps + docker + frontend)
    bash setup.sh --down   Stop whole system (docker services + frontend)
    bash setup.sh --clean  Full reset (stop all + remove volumes + remove local runtime artifacts)
EOF
}

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Error: '$1' is required but not installed."
        exit 1
    fi
}

retry() {
    local max_attempts="$1"
    shift
    local attempt
    for attempt in $(seq 1 "$max_attempts"); do
        if "$@"; then
            return 0
        fi
        local status="$?"
        if [ "$attempt" -eq "$max_attempts" ]; then
            return "$status"
        fi
        echo "Command failed with exit code ${status}; retrying (${attempt}/${max_attempts})..."
        sleep $((attempt * 10))
    done
}

stop_frontend() {
    if [ -f "$FRONTEND_PID_FILE" ]; then
        old_pid="$(cat "$FRONTEND_PID_FILE" || true)"
        if [ -n "${old_pid}" ] && kill -0 "$old_pid" >/dev/null 2>&1; then
            echo "Stopping frontend process: ${old_pid}"
            kill "$old_pid" >/dev/null 2>&1 || true
        fi
        rm -f "$FRONTEND_PID_FILE"
    fi
}

do_down() {
    require_cmd docker
    ensure_env_file

    echo "[1/2] Stopping frontend..."
    stop_frontend

    echo "[2/2] Stopping Docker services..."
    if [ -f "$AUTO_COMPOSE_OVERRIDE" ]; then
        docker compose -f docker-compose.yaml -f "$AUTO_COMPOSE_OVERRIDE" --env-file .env down --remove-orphans
    else
        docker compose --env-file .env down --remove-orphans
    fi

    echo
    echo "System stopped successfully."
}

do_clean() {
    require_cmd docker
    ensure_env_file

    echo "[1/4] Stopping frontend..."
    stop_frontend

    echo "[2/4] Stopping Docker services and removing volumes..."
    if [ -f "$AUTO_COMPOSE_OVERRIDE" ]; then
        docker compose -f docker-compose.yaml -f "$AUTO_COMPOSE_OVERRIDE" --env-file .env down -v --remove-orphans
    else
        docker compose --env-file .env down -v --remove-orphans
    fi

    echo "[3/4] Removing generated runtime files..."
    rm -f "$AUTO_PORTS_FILE" "$AUTO_COMPOSE_OVERRIDE" "$FRONTEND_LOG" "$FRONTEND_PID_FILE" "$DEPS_HASH_FILE"

    echo "[4/4] Removing local Python environment and demo outputs..."
    rm -rf "${PROJECT_ROOT}/.venv" "${PROJECT_ROOT}/frontend/demo_outputs"

    echo
    echo "System cleaned successfully (full reset complete)."
}

do_up() {
    echo "[1/7] Checking required tools..."
    require_cmd docker
    require_cmd bash
    ensure_env_file

    echo "[2/7] Ensuring uv is installed..."
    if ! command -v uv >/dev/null 2>&1; then
        curl -LsSf https://astral.sh/uv/install.sh | sh
        if [ -f "$HOME/.local/bin/env" ]; then
            # shellcheck disable=SC1090
            source "$HOME/.local/bin/env"
        fi
    fi

    if ! command -v uv >/dev/null 2>&1; then
        echo "Error: uv installation failed or uv is not in PATH."
        exit 1
    fi

    echo "[3/7] Creating and activating virtual environment..."
    if [ -d ".venv" ]; then
        echo "Found existing .venv, reusing it (no replacement prompt)."
    else
        uv venv
    fi
    if [ -f ".venv/bin/activate" ]; then
        # shellcheck disable=SC1091
        source .venv/bin/activate
    elif [ -f ".venv/Scripts/activate" ]; then
        # shellcheck disable=SC1091
        source .venv/Scripts/activate
    else
        echo "Error: Could not find venv activation script (.venv/bin/activate or .venv/Scripts/activate)."
        exit 1
    fi

    echo "[4/7] Installing Python dependencies..."
    current_deps_hash="$(python - <<'PY'
import hashlib
from pathlib import Path

paths = [
    Path("requirements.txt"),
    Path("shared/setup.py"),
]

h = hashlib.sha256()
for p in paths:
    h.update(str(p).encode("utf-8"))
    h.update(b"\n")
    h.update(p.read_bytes())
    h.update(b"\n")
print(h.hexdigest())
PY
)"

previous_deps_hash=""
if [ -f "$DEPS_HASH_FILE" ]; then
    previous_deps_hash="$(cat "$DEPS_HASH_FILE" || true)"
fi

if [ "$current_deps_hash" = "$previous_deps_hash" ]; then
    echo "Dependencies unchanged, skipping uv pip install."
else
    echo "Dependency changes detected, installing/updating packages..."
    retry 3 uv pip install -r requirements.txt
    retry 3 uv pip install -e shared/
    echo "$current_deps_hash" > "$DEPS_HASH_FILE"
fi

    echo "[5/7] Calculating free host ports (auto-avoid conflicts)..."

find_free_port() {
    local start_port="$1"
    local py_exec
    py_exec="$(command -v python || command -v python3)"
    if [ -z "${py_exec:-}" ]; then
        echo "Error: python/python3 not found for port detection."
        exit 1
    fi

    "$py_exec" - "$start_port" <<'PY'
import socket
import sys

start = int(sys.argv[1])
for port in range(start, start + 1000):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                try:
                        s.bind(("0.0.0.0", port))
                        print(port)
                        raise SystemExit(0)
                except OSError:
                        pass
raise SystemExit(1)
PY
}

REDIS_PORT="$(find_free_port "${REDIS_PORT:-6379}")"
MINIO_API_PORT="$(find_free_port "${MINIO_API_PORT:-9000}")"
MINIO_CONSOLE_PORT="$(find_free_port "${MINIO_CONSOLE_PORT:-9001}")"
API_SERVICE_PORT="$(find_free_port "${API_SERVICE_PORT:-8002}")"
PDF_SERVICE_PORT="$(find_free_port "${PDF_SERVICE_PORT:-8003}")"
PDF_API_PORT="$(find_free_port "${PDF_API_PORT:-8004}")"
TTS_SERVICE_PORT="$(find_free_port "${TTS_SERVICE_PORT:-8889}")"
AGENT_SERVICE_PORT="$(find_free_port "${AGENT_SERVICE_PORT:-8964}")"
JAEGER_UI_PORT="$(find_free_port "${JAEGER_UI_PORT:-16686}")"
OTLP_GRPC_PORT="$(find_free_port "${OTLP_GRPC_PORT:-4317}")"
OTLP_HTTP_PORT="$(find_free_port "${OTLP_HTTP_PORT:-4318}")"
FRONTEND_PORT="$(find_free_port "${FRONTEND_PORT:-7860}")"

cat > "$AUTO_PORTS_FILE" <<EOF
REDIS_PORT=${REDIS_PORT}
MINIO_API_PORT=${MINIO_API_PORT}
MINIO_CONSOLE_PORT=${MINIO_CONSOLE_PORT}
API_SERVICE_PORT=${API_SERVICE_PORT}
PDF_SERVICE_PORT=${PDF_SERVICE_PORT}
PDF_API_PORT=${PDF_API_PORT}
TTS_SERVICE_PORT=${TTS_SERVICE_PORT}
AGENT_SERVICE_PORT=${AGENT_SERVICE_PORT}
JAEGER_UI_PORT=${JAEGER_UI_PORT}
OTLP_GRPC_PORT=${OTLP_GRPC_PORT}
OTLP_HTTP_PORT=${OTLP_HTTP_PORT}
FRONTEND_PORT=${FRONTEND_PORT}
EOF

cat > "$AUTO_COMPOSE_OVERRIDE" <<EOF
services:
    redis:
        ports:
            - "${REDIS_PORT}:6379"

    minio:
        ports:
            - "${MINIO_API_PORT}:9000"
            - "${MINIO_CONSOLE_PORT}:9001"

    api-service:
        ports:
            - "${API_SERVICE_PORT}:8002"

    agent-service:
        ports:
            - "${AGENT_SERVICE_PORT}:8964"

    pdf-service:
        ports:
            - "${PDF_SERVICE_PORT}:8003"

    tts-service:
        ports:
            - "${TTS_SERVICE_PORT}:8889"

    jaeger:
        ports:
            - "${JAEGER_UI_PORT}:16686"
            - "${OTLP_GRPC_PORT}:4317"
            - "${OTLP_HTTP_PORT}:4318"

    pdf-api:
        ports:
            - "${PDF_API_PORT}:8004"
EOF

    echo "[6/7] Starting all Docker services..."
    docker compose -f docker-compose.yaml -f "$AUTO_COMPOSE_OVERRIDE" --env-file .env up --build -d

    echo "[7/7] Starting frontend..."
    mkdir -p "${PROJECT_ROOT}/frontend/demo_outputs"

    stop_frontend

    export API_SERVICE_URL="http://localhost:${API_SERVICE_PORT}"
    export FRONTEND_PORT

    nohup python -m frontend > "$FRONTEND_LOG" 2>&1 &
    frontend_pid="$!"
    echo "$frontend_pid" > "$FRONTEND_PID_FILE"
    disown "$frontend_pid" >/dev/null 2>&1 || true

    echo
    echo "Bootstrap completed successfully."
    echo ""
    echo "Service endpoints:"
    echo "- Frontend:         http://localhost:${FRONTEND_PORT}"
    echo "- API Docs:         http://localhost:${API_SERVICE_PORT}/docs"
    echo "- API Health:       http://localhost:${API_SERVICE_PORT}/health"
    echo "- Agent Service:    http://localhost:${AGENT_SERVICE_PORT}"
    echo "- PDF Service:      http://localhost:${PDF_SERVICE_PORT}"
    echo "- TTS Service:      http://localhost:${TTS_SERVICE_PORT}"
    echo "- TTS Voices:       http://localhost:${TTS_SERVICE_PORT}/voices"
    echo "- MinIO API:        http://localhost:${MINIO_API_PORT}"
    echo "- MinIO Console:    http://localhost:${MINIO_CONSOLE_PORT}"
    echo "- Jaeger:           http://localhost:${JAEGER_UI_PORT}"
    echo "- Redis:            localhost:${REDIS_PORT}"
    echo ""
    echo "Generated files:"
    echo "- Port map env:     ${AUTO_PORTS_FILE}"
    echo "- Compose override: ${AUTO_COMPOSE_OVERRIDE}"
    echo "- Frontend log:     ${FRONTEND_LOG}"
}

if [ "$#" -ne 1 ]; then
    usage
    exit 1
fi

case "$1" in
    --up)
        do_up
        ;;
    --down)
        do_down
        ;;
    --clean)
        do_clean
        ;;
    *)
        usage
        exit 1
        ;;
esac
