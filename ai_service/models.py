"""Pydantic models for AI service request/response."""

from pydantic import BaseModel
from typing import Optional


class AnalysisRequest(BaseModel):
    symbol: str
    price_data: dict
    technical_data: Optional[dict] = None
    news_data: Optional[dict] = None


class AnalysisResponse(BaseModel):
    symbol: str
    summary: str
    sentiment: str
    recommendation: str
    confidence: float
    key_factors: list[str] = []
    risk_level: str = "medium"
    details: dict = {}


class NewsAnalysisRequest(BaseModel):
    symbol: str
    headline: str
    content: Optional[str] = None
    source: Optional[str] = None


class NewsAnalysisResponse(BaseModel):
    symbol: str
    impact: str
    summary: str
    sentiment_score: float
    key_factors: list[str] = []


class BriefingRequest(BaseModel):
    watchlist_data: list[dict]
    user_timezone: str = "US/Eastern"


class BriefingResponse(BaseModel):
    title: str
    sections: list[dict]
    overall_sentiment: str


class HealthResponse(BaseModel):
    status: str
    service: str
    model: str = "gemini-2.5-flash"
    version: str = "2.0.0"
