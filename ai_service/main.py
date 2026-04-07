"""FastAPI application for AI-powered stock analysis using Gemini 2.5 Flash.

Security measures:
  - Rate limiting per endpoint to prevent denial-of-wallet attacks on Gemini API.
  - Input validation via Pydantic models with strict field constraints.
  - CORS restricted to known origins (configurable via env).
  - No API key exposure — key is read once and never logged or serialized.
"""

from __future__ import annotations

import logging
import os
import time
from collections import defaultdict
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from dotenv import load_dotenv
from pydantic import ValidationError

from models import (
    AnalysisRequest,
    AnalysisResponse,
    BriefingRequest,
    BriefingResponse,
    HealthResponse,
    NewsAnalysisRequest,
    NewsAnalysisResponse,
)
from analyzer import StockAnalyzer

load_dotenv()

logging.basicConfig(
    level=getattr(logging, os.getenv("LOG_LEVEL", "INFO").upper(), logging.INFO),
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Rate limiter (in-process, per-IP, sliding window)
# ---------------------------------------------------------------------------

RATE_LIMIT_REQUESTS = int(os.getenv("RATE_LIMIT_REQUESTS", "30"))
RATE_LIMIT_WINDOW = int(os.getenv("RATE_LIMIT_WINDOW", "60"))  # seconds

_rate_buckets: dict[str, list[float]] = defaultdict(list)


def _check_rate_limit(client_ip: str) -> bool:
    """Return True if the request should be allowed."""
    now = time.monotonic()
    window_start = now - RATE_LIMIT_WINDOW
    bucket = _rate_buckets[client_ip]
    # Prune old entries
    _rate_buckets[client_ip] = [t for t in bucket if t > window_start]
    if len(_rate_buckets[client_ip]) >= RATE_LIMIT_REQUESTS:
        return False
    _rate_buckets[client_ip].append(now)
    return True


# ---------------------------------------------------------------------------
# App lifecycle
# ---------------------------------------------------------------------------

analyzer: StockAnalyzer | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global analyzer
    api_key = os.getenv("GOOGLE_AI_API_KEY", "")
    analyzer = StockAnalyzer(api_key=api_key)
    if api_key:
        logger.info("StockPulse AI Service started with Gemini 2.5 Flash")
    else:
        logger.warning("No GOOGLE_AI_API_KEY set — running in fallback mode")
    yield
    logger.info("StockPulse AI Service shutting down")


app = FastAPI(
    title="StockPulse AI Service",
    version="2.1.0",
    lifespan=lifespan,
)

# ---------------------------------------------------------------------------
# CORS — restrict to known origins in production
# ---------------------------------------------------------------------------

ALLOWED_ORIGINS = os.getenv(
    "CORS_ORIGINS", "http://localhost:3000,http://localhost:5173"
).split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in ALLOWED_ORIGINS],
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Middleware — rate limiting
# ---------------------------------------------------------------------------

@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    # Skip rate limiting for health checks
    if request.url.path == "/health":
        return await call_next(request)

    client_ip = request.client.host if request.client else "unknown"
    if not _check_rate_limit(client_ip):
        logger.warning("Rate limit exceeded for %s on %s", client_ip, request.url.path)
        return JSONResponse(
            status_code=429,
            content={"detail": "Rate limit exceeded. Try again later."},
        )
    return await call_next(request)


# ---------------------------------------------------------------------------
# Global exception handler for validation errors
# ---------------------------------------------------------------------------

@app.exception_handler(ValidationError)
async def validation_exception_handler(request: Request, exc: ValidationError):
    return JSONResponse(
        status_code=422,
        content={"detail": exc.errors()},
    )


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.get("/health", response_model=HealthResponse)
async def health():
    return HealthResponse(
        status="ok" if analyzer and analyzer.client else "degraded",
        service="stockpulse-ai",
    )


@app.post("/analyze", response_model=AnalysisResponse)
async def analyze(request: AnalysisRequest):
    if not analyzer:
        raise HTTPException(status_code=503, detail="Service not initialized")
    return await analyzer.analyze(request)


@app.post("/analyze_news", response_model=NewsAnalysisResponse)
async def analyze_news(request: NewsAnalysisRequest):
    if not analyzer:
        raise HTTPException(status_code=503, detail="Service not initialized")
    return await analyzer.analyze_news(request)


@app.post("/daily_briefing", response_model=BriefingResponse)
async def daily_briefing(request: BriefingRequest):
    if not analyzer:
        raise HTTPException(status_code=503, detail="Service not initialized")
    return await analyzer.daily_briefing(request)
