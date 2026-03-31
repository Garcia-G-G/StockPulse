"""FastAPI application for AI-powered stock analysis."""

import os
from fastapi import FastAPI
from dotenv import load_dotenv
from models import AnalysisRequest, AnalysisResponse, HealthResponse
from analyzer import StockAnalyzer

load_dotenv()

app = FastAPI(title="StockPulse AI Service", version="1.0.0")

analyzer = StockAnalyzer(api_key=os.getenv("GOOGLE_AI_API_KEY", ""))


@app.get("/health", response_model=HealthResponse)
async def health():
    return HealthResponse(status="ok", service="stockpulse-ai")


@app.post("/analyze", response_model=AnalysisResponse)
async def analyze(request: AnalysisRequest):
    return await analyzer.analyze(request)
