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
    details: dict


class HealthResponse(BaseModel):
    status: str
    service: str
