# syntax=docker/dockerfile:1.7
# ===========================================================================
# Atlas RAG - production image
# Two stages so the ~700 MB of build toolchain used to compile wheels never
# reaches the runtime layer.
# ===========================================================================

# ---------- builder --------------------------------------------------------
FROM python:3.11-slim AS builder

ENV PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential git curl && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY requirements.txt requirements-min.txt ./

# BUILD_PROFILE=full  -> LlamaIndex + Qdrant + Docling (the graded stack)
# BUILD_PROFILE=min   -> API + LangGraph + lite retrieval (fast CI / free tiers)
ARG BUILD_PROFILE=full
RUN python -m venv /opt/venv && \
    /opt/venv/bin/pip install --upgrade pip && \
    if [ "$BUILD_PROFILE" = "min" ]; then \
      /opt/venv/bin/pip install -r requirements-min.txt ; \
    else \
      /opt/venv/bin/pip install -r requirements.txt ; \
    fi

# ---------- runtime --------------------------------------------------------
FROM python:3.11-slim AS runtime

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    HF_HOME=/app/.cache/hf \
    APP_HOST=0.0.0.0 \
    APP_PORT=8000 \
    APP_ENV=production

RUN apt-get update && apt-get install -y --no-install-recommends \
      libgl1 libglib2.0-0 curl && rm -rf /var/lib/apt/lists/* \
 && useradd --create-home --uid 10001 atlas

COPY --from=builder /opt/venv /opt/venv

WORKDIR /app
COPY --chown=atlas:atlas atlas/    ./atlas/
COPY --chown=atlas:atlas scripts/  ./scripts/
COPY --chown=atlas:atlas web/      ./web/
COPY --chown=atlas:atlas data/     ./data/
COPY --chown=atlas:atlas tests/    ./tests/
COPY --chown=atlas:atlas requirements*.txt README.md ./

RUN mkdir -p /app/storage /app/.cache && chown -R atlas:atlas /app
USER atlas

EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
  CMD curl -fsS "http://localhost:${APP_PORT}/api/health" || exit 1

# Single worker on purpose: the in-process index and the warmed LangGraph are
# per-process state. Scale out with replicas behind the load balancer, not with
# --workers, so each replica keeps one warm index.
CMD ["sh", "-c", "python scripts/ingest.py || true; exec uvicorn atlas.api.main:app --host 0.0.0.0 --port ${APP_PORT} --workers 1 --timeout-keep-alive 75"]
