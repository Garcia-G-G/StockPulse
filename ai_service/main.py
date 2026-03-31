"""FastAPI application for AI-powered stock analysis."""

from __future__ import annotations

import hashlib
import json
import logging
import os
import traceback
from datetime import datetime

import redis
from dotenv import load_dotenv
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from analyzer import GeminiAnalyzer
from fallback import FallbackAnalyzer
from models import (
    BriefingRequest,
    BriefingResponse,
    ErrorResponse,
    HealthResponse,
    ImportanceEvaluationRequest,
    ImportanceEvaluationResponse,
    NewsAnalysisRequest,
    NewsAnalysisResponse,
    PriceAnalysisRequest,
    PriceAnalysisResponse,
)

load_dotenv()

logging.basicConfig(
    level=getattr(logging, os.getenv("LOG_LEVEL", "info").upper(), logging.INFO),
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("stockpulse_ai")

# --- App Setup ---

app = FastAPI(
    title="StockPulse AI Service",
    version="2.0.0",
    description="AI-powered financial analysis using Google Gemini",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Services ---

gemini = GeminiAnalyzer()
fallback = FallbackAnalyzer()

REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
REDIS_DB = int(os.getenv("REDIS_DB", "1"))

try:
    redis_client = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=REDIS_DB, decode_responses=True)
    redis_client.ping()
    logger.info("Redis connected: %s:%s/%s", REDIS_HOST, REDIS_PORT, REDIS_DB)
except redis.ConnectionError:
    redis_client = None
    logger.warning("Redis unavailable, caching and rate limiting disabled")

# --- Cache TTLs ---

CACHE_TTLS = {
    "price": 300,       # 5 minutes
    "news": 1800,       # 30 minutes
    "briefing": 7200,   # 2 hours
    "importance": 600,  # 10 minutes
}

RATE_LIMIT_MAX = 10
RATE_LIMIT_WINDOW = 60


# --- Rate Limiting ---


def check_rate_limit(ip: str) -> bool:
    """Returns True if request is allowed, False if rate limited."""
    if not redis_client:
        return True

    key = f"ratelimit:ai:{ip}"
    count = redis_client.get(key)
    if count and int(count) >= RATE_LIMIT_MAX:
        return False

    pipe = redis_client.pipeline()
    pipe.incr(key)
    pipe.expire(key, RATE_LIMIT_WINDOW)
    pipe.execute()
    return True


# --- Caching ---


def cache_key(endpoint: str, request_data: dict) -> str:
    raw = json.dumps(request_data, sort_keys=True, default=str)
    digest = hashlib.md5(raw.encode()).hexdigest()
    return f"ai_cache:{endpoint}:{digest}"


def get_cached(key: str) -> dict | None:
    if not redis_client:
        return None
    cached = redis_client.get(key)
    if cached:
        return json.loads(cached)
    return None


def set_cached(key: str, data: dict, ttl: int) -> None:
    if not redis_client:
        return
    redis_client.setex(key, ttl, json.dumps(data, default=str))


# --- Global Exception Handler ---


@app.exception_handler(Exception)
async def global_exception_handler(_request: Request, exc: Exception):
    logger.error("Unhandled exception: %s\n%s", exc, traceback.format_exc())
    return JSONResponse(
        status_code=500,
        content=ErrorResponse(
            error="Internal server error",
            detail=str(exc) if os.getenv("ENVIRONMENT") == "development" else None,
        ).model_dump(mode="json"),
    )


# --- Endpoints ---


@app.get("/health", response_model=HealthResponse)
async def health():
    redis_ok = False
    if redis_client:
        try:
            redis_ok = redis_client.ping()
        except redis.ConnectionError:
            pass

    gemini_ok = gemini.client is not None

    return HealthResponse(
        status="ok" if redis_ok and gemini_ok else "degraded",
        timestamp=datetime.utcnow(),
        services={"redis": redis_ok, "gemini": gemini_ok},
    )


@app.post("/analyze/price", response_model=PriceAnalysisResponse)
async def analyze_price(request: PriceAnalysisRequest, req: Request):
    if not check_rate_limit(req.client.host):
        return JSONResponse(status_code=429, content={"error": "Rate limit exceeded (10 RPM)"})

    key = cache_key("price", request.model_dump())
    cached = get_cached(key)
    if cached:
        return PriceAnalysisResponse(**cached, cached=True)

    try:
        result = await gemini.analyze_price(request)
    except Exception as e:
        logger.warning("Gemini price analysis failed, using fallback: %s", e)
        result = await fallback.analyze_price(request)

    set_cached(key, result.model_dump(), CACHE_TTLS["price"])
    return result


@app.post("/analyze/news", response_model=NewsAnalysisResponse)
async def analyze_news(request: NewsAnalysisRequest, req: Request):
    if not check_rate_limit(req.client.host):
        return JSONResponse(status_code=429, content={"error": "Rate limit exceeded (10 RPM)"})

    key = cache_key("news", request.model_dump())
    cached = get_cached(key)
    if cached:
        return NewsAnalysisResponse(**cached, cached=True)

    try:
        result = await gemini.analyze_news(request)
    except Exception as e:
        logger.warning("Gemini news analysis failed, using fallback: %s", e)
        result = await fallback.analyze_news(request)

    set_cached(key, result.model_dump(), CACHE_TTLS["news"])
    return result


@app.post("/briefing", response_model=BriefingResponse)
async def briefing(request: BriefingRequest, req: Request):
    if not check_rate_limit(req.client.host):
        return JSONResponse(status_code=429, content={"error": "Rate limit exceeded (10 RPM)"})

    key = cache_key("briefing", request.model_dump())
    cached = get_cached(key)
    if cached:
        return BriefingResponse(**cached, cached=True)

    try:
        result = await gemini.generate_briefing(request)
    except Exception as e:
        logger.warning("Gemini briefing failed, using fallback: %s", e)
        result = await fallback.generate_briefing(request)

    set_cached(key, result.model_dump(), CACHE_TTLS["briefing"])
    return result


@app.post("/evaluate", response_model=ImportanceEvaluationResponse)
async def evaluate(request: ImportanceEvaluationRequest, req: Request):
    if not check_rate_limit(req.client.host):
        return JSONResponse(status_code=429, content={"error": "Rate limit exceeded (10 RPM)"})

    key = cache_key("importance", request.model_dump())
    cached = get_cached(key)
    if cached:
        return ImportanceEvaluationResponse(**cached, cached=True)

    try:
        result = await gemini.evaluate_importance(request)
    except Exception as e:
        logger.warning("Gemini importance eval failed, using fallback: %s", e)
        result = await fallback.evaluate_importance(request)

    set_cached(key, result.model_dump(), CACHE_TTLS["importance"])
    return result
