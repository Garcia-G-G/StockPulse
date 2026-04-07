"""FastAPI application for AI-powered stock analysis using Gemini 2.5 Flash."""

import os
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from dotenv import load_dotenv
from models import (
    AnalysisRequest, AnalysisResponse,
    NewsAnalysisRequest, NewsAnalysisResponse,
    BriefingRequest, BriefingResponse,
    HealthResponse,
)
from analyzer import StockAnalyzer

load_dotenv()

logging.basicConfig(
    level=getattr(logging, os.getenv("LOG_LEVEL", "INFO").upper()),
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

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
    version="2.0.0",
    lifespan=lifespan,
)


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
