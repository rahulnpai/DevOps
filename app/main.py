import time
import logging
import os
from fastapi import FastAPI, Response
from prometheus_client import (
    Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
)
import uvicorn

# ── Logging ────────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger("devops-app")

# ── App ────────────────────────────────────────────────────────────────────────
APP_VERSION = os.getenv("APP_VERSION", "1.0.0")
APP_ENV     = os.getenv("APP_ENV", "production")

app = FastAPI(
    title="DevOps MCA Production API",
    description="Production-grade FastAPI service with full observability",
    version=APP_VERSION,
    docs_url="/docs",
    redoc_url="/redoc",
)

# ── Prometheus metrics ─────────────────────────────────────────────────────────
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status"],
)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency",
    ["method", "endpoint"],
    buckets=[0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0],
)
IN_PROGRESS = Gauge(
    "http_requests_in_progress",
    "In-progress HTTP requests",
    ["method", "endpoint"],
)
APP_INFO = Gauge(
    "app_info",
    "Application metadata",
    ["version", "env"],
)
APP_INFO.labels(version=APP_VERSION, env=APP_ENV).set(1)


# ── Middleware ─────────────────────────────────────────────────────────────────
@app.middleware("http")
async def metrics_middleware(request, call_next):
    method   = request.method
    endpoint = request.url.path
    IN_PROGRESS.labels(method=method, endpoint=endpoint).inc()
    start = time.time()
    try:
        response = await call_next(request)
        status   = response.status_code
    except Exception as exc:
        status = 500
        raise exc
    finally:
        latency = time.time() - start
        REQUEST_COUNT.labels(method=method, endpoint=endpoint, status=status).inc()
        REQUEST_LATENCY.labels(method=method, endpoint=endpoint).observe(latency)
        IN_PROGRESS.labels(method=method, endpoint=endpoint).dec()
        logger.info(
            "method=%s path=%s status=%s latency=%.4fs",
            method, endpoint, status, latency,
        )
    return response


# ── Routes ─────────────────────────────────────────────────────────────────────
@app.get("/", tags=["root"])
async def root():
    return {
        "service": "DevOps MCA Production API",
        "version": APP_VERSION,
        "environment": APP_ENV,
        "status": "running",
    }


@app.get("/health", tags=["observability"])
async def health():
    return {
        "status": "healthy",
        "version": APP_VERSION,
        "environment": APP_ENV,
        "checks": {
            "api": "ok",
            "memory": "ok",
        },
    }


@app.get("/metrics", tags=["observability"])
async def metrics():
    data = generate_latest()
    return Response(content=data, media_type=CONTENT_TYPE_LATEST)


@app.get("/ready", tags=["observability"])
async def readiness():
    """Kubernetes readiness probe."""
    return {"status": "ready"}


@app.get("/live", tags=["observability"])
async def liveness():
    """Kubernetes liveness probe."""
    return {"status": "alive"}


# ── Entrypoint ─────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        workers=int(os.getenv("WORKERS", 1)),
        log_level="info",
        access_log=True,
    )
